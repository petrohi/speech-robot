/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright © 2019-2022 Tensil AI Company */

#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include "platform.h"
#include "xil_printf.h"
#include "xgpio_l.h"
#include "xaxidma.h"
#include "xtmrctr.h"

#include "architecture_params.h"
#include "tensil/architecture.h"
#include "tensil/instruction.h"
#include "tensil/tcu.h"
#include "tensil/instruction_buffer.h"
#include "tensil/dram.h"

#define ACQ_DT float

#define ACQ_PACKET_LENGTH 128
#define ACQ_PACKET_SIZE (ACQ_PACKET_LENGTH * sizeof(ACQ_DT))
#define ACQ_PACKET_DOUBLE_SIZE (2 * ACQ_PACKET_SIZE)

#define RFFT_TX_PACKET_SIZE ACQ_PACKET_DOUBLE_SIZE

#define RFFT_TX_FRAME_WIDTH (2 * ACQ_PACKET_LENGTH)
#define RFFT_TX_FRAME_LINE_SIZE (RFFT_TX_FRAME_WIDTH * sizeof(MODEL_DT))
#define RFFT_TX_FRAME_HEIGHT 124
#define RFFT_FRAME_HALF_PACKETS (RFFT_TX_FRAME_HEIGHT / 2)
#define RFFT_TX_FRAME_SIZE (RFFT_TX_FRAME_HEIGHT * RFFT_TX_FRAME_LINE_SIZE)

#define MODEL_DT int16_t
#define MODEL_DT_MIN INT16_MIN

#define MODEL_VECTOR_LENGTH TENSIL_ARCHITECTURE_ARRAY_SIZE
#define MODEL_VECTOR_SIZE (MODEL_VECTOR_LENGTH * sizeof(MODEL_DT))

#define MODEL_DRAM0_BUFFER_NUMBER 4

#define MODEL_INPUT_WIDTH 129
#define MODEL_INPUT_LINE_SIZE (MODEL_INPUT_WIDTH * MODEL_VECTOR_SIZE)
#define MODEL_INPUT_HEIGHT RFFT_TX_FRAME_HEIGHT
#define MODEL_INPUT_STEP (MODEL_INPUT_HEIGHT / MODEL_DRAM0_BUFFER_NUMBER)
#define MODEL_INPUT_SIZE (MODEL_INPUT_HEIGHT * MODEL_INPUT_LINE_SIZE)

#define MODEL_OUTPUT_LENGTH 12

#define MODEL_PROG_BASE (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + 0x400000)
#define MODEL_PROG_SIZE 642464

#define MODEL_CONST_BASE (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + 0x500000)
#define MODEL_CONST_SIZE_VECTORS 93937

#define EXP_DT double

#define EXP_TX_PACKET_SIZE (MODEL_OUTPUT_LENGTH * sizeof(MODEL_DT))
#define EXP_RX_PACKET_SIZE (MODEL_OUTPUT_LENGTH * sizeof(EXP_DT))

#define BUFFER_ALIGNMENT 0x10000
#define BUFFER_ALIGN(s) (s / BUFFER_ALIGNMENT + 1) * BUFFER_ALIGNMENT
#define BUFFER_START ((u8 *) XPAR_MIG7SERIES_0_BASEADDR)

static void print_float(EXP_DT f) {
	if (f < 0.0)
		print("-");

	int integer = abs((int) f);
	int fraction = abs((int) ((f - (double) integer) * 1e9));
	xil_printf("%d.%09d", integer, fraction);
}

static size_t argmax(size_t size, const EXP_DT *buffer, EXP_DT *max) {
	if (!size)
		return -1;

	*max = buffer[0];
	size_t max_i = 0;

	for (size_t i = 1; i < size; i++)
		if (buffer[i] > *max) {
			*max = buffer[i];
			max_i = i;
		}

	return max_i;
}

XAxiDma acq_axi_dma;
XAxiDma rfft_axi_dma;
XAxiDma exp_axi_dma;
XTmrCtr tmr_ctr;

const char *commands[MODEL_OUTPUT_LENGTH] = { "down", "go", "left", "no", "off",
		"on", "right", "stop", "up", "yes", "_silence_", "_unknown_" };

int main() {
	init_platform();

	int status;

	status = XTmrCtr_Initialize(&tmr_ctr, XPAR_TMRCTR_0_DEVICE_ID);

	if (status)
		goto error;

	u8* rfft_rx_bd_space = BUFFER_START;
	u8* rfft_tx_bd_space = rfft_rx_bd_space
			+ BUFFER_ALIGN(
					XAxiDma_BdRingMemCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, 1));

	u8 *acq_buffer_ptr = rfft_tx_bd_space
			+ BUFFER_ALIGN(
					XAxiDma_BdRingMemCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, 2));
	u8 *rfft_tx_buffer_ptr = acq_buffer_ptr
			+ BUFFER_ALIGN(ACQ_PACKET_DOUBLE_SIZE);
	u8 *rfft_rx_buffer_ptr = rfft_tx_buffer_ptr
			+ BUFFER_ALIGN(RFFT_TX_PACKET_SIZE);

	u8 *drma0_buffer_ptrs[MODEL_DRAM0_BUFFER_NUMBER];

	drma0_buffer_ptrs[0] =
			rfft_rx_buffer_ptr + BUFFER_ALIGN(RFFT_TX_FRAME_SIZE);

	for (size_t i = 1; i < MODEL_DRAM0_BUFFER_NUMBER; i++) {
		drma0_buffer_ptrs[i] =
				drma0_buffer_ptrs[i - 1]
						+ BUFFER_ALIGN(
								TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
	}

	u8 *dram1_buffer_ptr =
			drma0_buffer_ptrs[MODEL_DRAM0_BUFFER_NUMBER - 1]
					+ BUFFER_ALIGN(
							TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
	u8 *prog_buffer_ptr =
			dram1_buffer_ptr
					+ BUFFER_ALIGN(
							TENSIL_ARCHITECTURE_DRAM1_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));

	u8 *exp_rx_buffer_ptr = prog_buffer_ptr + BUFFER_ALIGN(MODEL_PROG_SIZE);

	XAxiDma_Config *acq_cfg_ptr = XAxiDma_LookupConfig(
	XPAR_ACQUISITION_AXI_DMA_0_DEVICE_ID);
	status = XAxiDma_CfgInitialize(&acq_axi_dma, acq_cfg_ptr);

	if (status)
		goto error;

	XGpio_WriteReg(XPAR_GPIO_0_BASEADDR, XGPIO_DATA_OFFSET, 0x1);

	XAxiDma_Config *rfft_cfg_ptr = XAxiDma_LookupConfig(
	XPAR_RFFT_AXI_DMA_0_DEVICE_ID);
	status = XAxiDma_CfgInitialize(&rfft_axi_dma, rfft_cfg_ptr);

	if (status)
		goto error;

	XAxiDma_BdRing *rfft_rx_ring_ptr = XAxiDma_GetRxRing(&rfft_axi_dma);
	XAxiDma_BdRing *rfft_tx_ring_ptr = XAxiDma_GetTxRing(&rfft_axi_dma);

	XAxiDma_BdRingIntDisable(rfft_rx_ring_ptr, XAXIDMA_IRQ_ALL_MASK);
	XAxiDma_BdRingIntDisable(rfft_tx_ring_ptr, XAXIDMA_IRQ_ALL_MASK);

	XAxiDma_BdRingSetCoalesce(rfft_rx_ring_ptr, 1, 0);
	XAxiDma_BdRingSetCoalesce(rfft_tx_ring_ptr, 1, 0);

	status = XAxiDma_BdRingCreate(rfft_rx_ring_ptr, (UINTPTR) rfft_rx_bd_space,
			(UINTPTR) rfft_rx_bd_space, XAXIDMA_BD_MINIMUM_ALIGNMENT, 1);

	if (status)
		goto error;

	status = XAxiDma_BdRingCreate(rfft_tx_ring_ptr, (UINTPTR) rfft_tx_bd_space,
			(UINTPTR) rfft_tx_bd_space, XAXIDMA_BD_MINIMUM_ALIGNMENT, 2);

	if (status)
		goto error;

	XAxiDma_Bd bd_template;
	XAxiDma_BdClear(&bd_template);

	status = XAxiDma_BdRingClone(rfft_rx_ring_ptr, &bd_template);

	if (status)
		goto error;

	status = XAxiDma_BdRingClone(rfft_tx_ring_ptr, &bd_template);

	if (status)
		goto error;

	status = XAxiDma_BdRingStart(rfft_rx_ring_ptr);

	if (status)
		goto error;

	status = XAxiDma_BdRingStart(rfft_tx_ring_ptr);

	if (status)
		goto error;

	memset((void *) acq_buffer_ptr, 0, ACQ_PACKET_DOUBLE_SIZE);
	memset((void *) rfft_tx_buffer_ptr, 0, RFFT_TX_PACKET_SIZE);
	memset((void *) rfft_rx_buffer_ptr, 0, RFFT_TX_FRAME_SIZE);

	struct architecture arch = { .array_size = TENSIL_ARCHITECTURE_ARRAY_SIZE,
			.data_type = TENSIL_ARCHITECTURE_DATA_TYPE, .local_depth =
			TENSIL_ARCHITECTURE_LOCAL_DEPTH, .accumulator_depth =
			TENSIL_ARCHITECTURE_ACCUMULATOR_DEPTH, .dram0_depth =
			TENSIL_ARCHITECTURE_DRAM0_DEPTH, .dram1_depth =
			TENSIL_ARCHITECTURE_DRAM1_DEPTH, .stride0_depth =
			TENSIL_ARCHITECTURE_STRIDE0_DEPTH, .stride1_depth =
			TENSIL_ARCHITECTURE_STRIDE1_DEPTH, .simd_registers_depth =
			TENSIL_ARCHITECTURE_SIMD_REGISTERS_DEPTH, };

	if (!architecture_is_valid(&arch))
		goto error;

	struct instruction_layout layout;

	instruction_layout_init(&layout, &arch);

	struct tcu tcu;
	error_t error = ERROR_NONE;

	error = tcu_init(&tcu);

	if (error)
		goto error;

	struct instruction_buffer buffer = { .ptr = prog_buffer_ptr, .size =
			0x100000, .offset = 0 };
	buffer_reset(&buffer);

	error = buffer_append_config_instruction(&buffer, &layout,
	CONFIG_REGISTER_DRAM0_OFFSET, 0);

	if (error)
		goto error;

	error = buffer_append_config_instruction(&buffer, &layout,
	CONFIG_REGISTER_DRAM1_OFFSET, CONFIG_DRAM_OFFSET(dram1_buffer_ptr));

	if (error)
		goto error;

	error = buffer_append_config_instruction(&buffer, &layout,
	CONFIG_REGISTER_TIMEOUT, 100);

	if (error)
		goto error;

	memcpy((void *) dram1_buffer_ptr, (const void*) MODEL_CONST_BASE,
			MODEL_CONST_SIZE_VECTORS * TENSIL_ARCHITECTURE_ARRAY_SIZE
					* sizeof(MODEL_DT));

	//Xil_DCacheFlushRange((UINTPTR)Dram0BufferPtr, TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
	//Xil_DCacheFlushRange((UINTPTR)dram1_buffer_ptr, TENSIL_ARCHITECTURE_DRAM1_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));

	error = buffer_append_program(&buffer, (const u8*) MODEL_PROG_BASE,
			MODEL_PROG_SIZE);

	if (error)
		goto error;

	error = buffer_append_instruction(&buffer, &layout, OPCODE_DATA_MOVE,
	DATA_MOVE_FLAG_DRAM0_TO_LOCAL, 0, TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1, 0);

	if (error)
		goto error;

	error = buffer_append_instruction(&buffer, &layout, OPCODE_DATA_MOVE,
	DATA_MOVE_FLAG_LOCAL_TO_DRAM0, 0, TENSIL_ARCHITECTURE_DRAM0_DEPTH - 2, 0);

	if (error)
		goto error;

	error = buffer_pad_to_alignment(&buffer, &layout,
			tcu_get_instructions_data_width_bytes(&tcu));

	if (error)
		goto error;

	XAxiDma_Config *exp_cfg_ptr = XAxiDma_LookupConfig(
			XPAR_EXP_AXI_DMA_0_DEVICE_ID);
	status = XAxiDma_CfgInitialize(&exp_axi_dma, exp_cfg_ptr);

	if (status)
		goto error;

	print("Ready!\r\n");

	int acq_reversed = 0;
	int rfft_line = 0;

	size_t instructions_run_offset = 0;

	while (true) {
		size_t acq_offset = (1 - acq_reversed) * ACQ_PACKET_SIZE;

		status = XAxiDma_SimpleTransfer(&acq_axi_dma,
				(UINTPTR) (acq_buffer_ptr + acq_offset),
				ACQ_PACKET_SIZE, XAXIDMA_DEVICE_TO_DMA);

		if (status)
			goto error;

		acq_reversed = (acq_reversed + 1) % 2;
		acq_offset = (1 - acq_reversed) * ACQ_PACKET_SIZE;

		memcpy((void*) (rfft_tx_buffer_ptr + acq_offset),
				(const void*) (acq_buffer_ptr + acq_offset),
				ACQ_PACKET_SIZE);

		XAxiDma_Bd *rfft_rx_bd_head_ptr;
		status = XAxiDma_BdRingAlloc(rfft_tx_ring_ptr, 2, &rfft_rx_bd_head_ptr);

		if (status)
			goto error;

		XAxiDma_Bd *cur_bd_ptr = rfft_rx_bd_head_ptr;
		for (size_t i = 0; i < 2; i++) {
			size_t tx_offset = abs(i - acq_reversed) * ACQ_PACKET_SIZE;

			status = XAxiDma_BdSetBufAddr(cur_bd_ptr,
					(UINTPTR) (rfft_tx_buffer_ptr + tx_offset));

			if (status)
				goto error;

			status = XAxiDma_BdSetLength(cur_bd_ptr, ACQ_PACKET_SIZE,
					rfft_tx_ring_ptr->MaxTransferLen);

			if (status)
				goto error;

			XAxiDma_BdSetCtrl(cur_bd_ptr,
					i ? XAXIDMA_BD_CTRL_TXEOF_MASK : XAXIDMA_BD_CTRL_TXSOF_MASK);
			XAxiDma_BdSetId(cur_bd_ptr, i);

			cur_bd_ptr = (XAxiDma_Bd *) XAxiDma_BdRingNext(rfft_tx_ring_ptr,
					cur_bd_ptr);
		}

		status = XAxiDma_BdRingToHw(rfft_tx_ring_ptr, 2, rfft_rx_bd_head_ptr);

		if (status)
			goto error;

		XAxiDma_Bd *rfft_rx_head_ptr;
		status = XAxiDma_BdRingAlloc(rfft_rx_ring_ptr, 1, &rfft_rx_head_ptr);

		if (status)
			goto error;

		cur_bd_ptr = rfft_rx_head_ptr;

		status = XAxiDma_BdSetBufAddr(cur_bd_ptr,
				(UINTPTR) (rfft_rx_buffer_ptr
						+ rfft_line * RFFT_TX_FRAME_LINE_SIZE));

		if (status)
			goto error;

		status = XAxiDma_BdSetLength(cur_bd_ptr, RFFT_TX_FRAME_LINE_SIZE,
				rfft_rx_ring_ptr->MaxTransferLen);

		if (status)
			goto error;

		XAxiDma_BdSetCtrl(cur_bd_ptr, 0);
		XAxiDma_BdSetId(cur_bd_ptr, 0);

		status = XAxiDma_BdRingToHw(rfft_rx_ring_ptr, 1, rfft_rx_head_ptr);

		if (status)
			goto error;

		while (XAxiDma_BdRingFromHw(rfft_rx_ring_ptr, XAXIDMA_ALL_BDS,
				&rfft_rx_head_ptr) != 1
				|| XAxiDma_BdRingFromHw(rfft_tx_ring_ptr, XAXIDMA_ALL_BDS,
						&rfft_rx_bd_head_ptr) != 2)
			;

		status = XAxiDma_BdRingFree(rfft_tx_ring_ptr, 2, rfft_rx_bd_head_ptr);

		if (status)
			goto error;

		status = XAxiDma_BdRingFree(rfft_rx_ring_ptr, 1, rfft_rx_head_ptr);

		if (status)
			goto error;

		size_t prepare_index = rfft_line / MODEL_INPUT_STEP;
		size_t infer_index =
				prepare_index ?
						prepare_index - 1 : MODEL_DRAM0_BUFFER_NUMBER - 1;

		u8 *dram0_prepare_buffer_ptr = drma0_buffer_ptrs[prepare_index];
		u8 *dram0_infer_buffer_ptr = drma0_buffer_ptrs[infer_index];

		if (rfft_line % MODEL_INPUT_STEP == 0) {
			if (instructions_run_offset/* || result_offset*/)
				goto error;
			// Inference took longer than 500ms

			size_t buffer_offset = buffer.offset;
			buffer.offset = 0;

			error = buffer_append_config_instruction(&buffer, &layout,
			CONFIG_REGISTER_DRAM0_OFFSET,
					CONFIG_DRAM_OFFSET(dram0_infer_buffer_ptr));

			buffer.offset = buffer_offset;

			dram_fill_scalars(dram0_infer_buffer_ptr, arch.data_type,
					(TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1) * arch.array_size, 0,
					arch.array_size);

			dram_fill_scalars(dram0_infer_buffer_ptr, arch.data_type,
					(TENSIL_ARCHITECTURE_DRAM0_DEPTH - 2) * arch.array_size,
					0xff, arch.array_size);

			error = tcu_start_instructions(&tcu, &buffer,
					&instructions_run_offset);

			if (error)
				goto error;

		}

		if (instructions_run_offset) {
			if (!tcu_is_instructions_busy(&tcu)) {
				if (instructions_run_offset == buffer.offset) {
					if (dram_compare_scalars(dram0_infer_buffer_ptr,
							arch.data_type,
							(TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1)
									* arch.array_size,
							(TENSIL_ARCHITECTURE_DRAM0_DEPTH - 2)
									* arch.array_size, arch.array_size) == 0) {

						status = XAxiDma_SimpleTransfer(&exp_axi_dma,
								(UINTPTR) (dram0_infer_buffer_ptr),
								EXP_TX_PACKET_SIZE, XAXIDMA_DMA_TO_DEVICE);

						if (status)
							goto error;

						status = XAxiDma_SimpleTransfer(&exp_axi_dma,
								(UINTPTR) (exp_rx_buffer_ptr),
								EXP_RX_PACKET_SIZE, XAXIDMA_DEVICE_TO_DMA);

						if (status)
							goto error;

						while (XAxiDma_Busy(&exp_axi_dma, XAXIDMA_DEVICE_TO_DMA))
							;


						EXP_DT softmax_buffer[MODEL_OUTPUT_LENGTH];
						EXP_DT sum = 0;

						memcpy((void *)softmax_buffer, (const void *)exp_rx_buffer_ptr, EXP_RX_PACKET_SIZE);

						for (size_t i = 0; i < MODEL_OUTPUT_LENGTH; i++)
							sum += softmax_buffer[i];

						for (size_t i = 0; i < MODEL_OUTPUT_LENGTH; i++)
							softmax_buffer[i] = softmax_buffer[i] / sum;

						EXP_DT max;
						size_t max_i = argmax(MODEL_OUTPUT_LENGTH, softmax_buffer, &max);

						if (max > 0.7) {
							print_float(max);
							print(" ");
							print(commands[max_i]);
							print("\r\n");
						}

						instructions_run_offset = 0;
					}

				} else {
					error = tcu_start_instructions(&tcu, &buffer,
							&instructions_run_offset);

					if (error)
						goto error;
				}
			}
		}

		for (size_t i = 0; i < MODEL_DRAM0_BUFFER_NUMBER; i++) {
			int shifted_line = rfft_line - i * MODEL_INPUT_STEP;

			size_t rfft_source_line =
					shifted_line < 0 ?
							RFFT_TX_FRAME_HEIGHT + shifted_line : shifted_line;
			size_t model_dest_line = (rfft_line % MODEL_INPUT_STEP)
					+ (MODEL_DRAM0_BUFFER_NUMBER - 1 - i) * MODEL_INPUT_STEP;

			u8 *rfft_rx_line_ptr = rfft_rx_buffer_ptr
					+ rfft_source_line * RFFT_TX_FRAME_LINE_SIZE;
			u8 *dram0_line_ptr = dram0_prepare_buffer_ptr
					+ model_dest_line * MODEL_INPUT_LINE_SIZE;

			memset((void*) dram0_line_ptr, 0, MODEL_INPUT_LINE_SIZE);

			for (size_t j = 0; j < MODEL_INPUT_WIDTH; j++) {
				((MODEL_DT *) dram0_line_ptr)[j * MODEL_VECTOR_LENGTH] =
						((MODEL_DT *) rfft_rx_line_ptr)[RFFT_TX_FRAME_WIDTH
								- (j + 1)];
			}
		}

		rfft_line = (rfft_line + 1) % RFFT_TX_FRAME_HEIGHT;

		XTmrCtr_Reset(&tmr_ctr, 0);
		XTmrCtr_Start(&tmr_ctr, 0);

		while (XAxiDma_Busy(&acq_axi_dma, XAXIDMA_DEVICE_TO_DMA))
			;

		XTmrCtr_Stop(&tmr_ctr, 0);
		u32 cycles = XTmrCtr_GetValue(&tmr_ctr, 0);

		if (cycles < 100000)
			xil_printf("CYCLES: %d\r\n", cycles);
	}

	/*for (size_t i = 0; i < MODEL_INPUT_HEIGHT; i++)
	 for (size_t j = 0; j < MODEL_INPUT_WIDTH; j++)
	 for (size_t k = 0; k < MODEL_VECTOR_LENGTH; k++) {
	 print_float((float)((MODEL_DT*) Dram0BufferPtr)[(i * MODEL_INPUT_WIDTH + j) * MODEL_VECTOR_LENGTH + k] / 256.0);

	 if (k == MODEL_VECTOR_LENGTH - 1)
	 xil_printf("\r\n");
	 else
	 xil_printf(",");
	 }*/

	error: cleanup_platform();
	return 0;
}
