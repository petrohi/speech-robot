/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright © 2019-2022 Tensil AI Company */

#include <stdlib.h>
#include <stdint.h>
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

XAxiDma AcqAxiDma;
XAxiDma RfftAxiDma;
XTmrCtr Timer;

/*void print_float(float f) {
	if (f < 0.0)
		print("-");

	int integer = abs((int) f);
	int fraction = abs((int) ((f - (float) integer) * 1e6));
	xil_printf("%d.%06d", integer, fraction);
}*/

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

#define MODEL_CONST_BASE (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + 0x500000)
#define MODEL_CONST_SIZE_VECTORS 93808

#define MODEL_PROG_BASE (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + 0x400000)
#define MODEL_PROG_SIZE 642064

#define ALIGNMENT 0x10000
#define ALIGN(s) (s / ALIGNMENT + 1) * ALIGNMENT

#define START ((u8 *) XPAR_MIG7SERIES_0_BASEADDR)

static size_t argmax(size_t size, const MODEL_DT *buffer, MODEL_DT *max, MODEL_DT *max2) {
	if (!size)
		return -1;

	*max = MODEL_DT_MIN;
	*max2 = MODEL_DT_MIN;
	size_t max_i = 0;

	for (size_t i = 0; i < size; i++)
		if (buffer[i] > *max) {
			*max = buffer[i];
			max_i = i;
		}

	for (size_t i = 0; i < size; i++)
		if (i != max_i && buffer[i] > *max2) {
			*max2 = buffer[i];
		}

	return max_i;
}

int main() {
	init_platform();

	int Status;

	Status = XTmrCtr_Initialize(&Timer, XPAR_TMRCTR_0_DEVICE_ID);

	if (Status)
		goto error;

	u8* RxBdSpace = START;
	u8* TxBdSpace = RxBdSpace
			+ ALIGN(XAxiDma_BdRingMemCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, 1));

	u8 *AcqBufferPtr = TxBdSpace
			+ ALIGN(XAxiDma_BdRingMemCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, 2));
	u8 *RfftTxBufferPtr = AcqBufferPtr + ALIGN(ACQ_PACKET_DOUBLE_SIZE);
	u8 *RfftRxBufferPtr = RfftTxBufferPtr + ALIGN(RFFT_TX_PACKET_SIZE);

	u8 *Dram0BufferPtrs[MODEL_DRAM0_BUFFER_NUMBER];

	Dram0BufferPtrs[0] = RfftRxBufferPtr + ALIGN(RFFT_TX_FRAME_SIZE);

	for (size_t i = 1; i < MODEL_DRAM0_BUFFER_NUMBER; i++) {
		Dram0BufferPtrs[i] =
				Dram0BufferPtrs[i - 1]
						+ ALIGN(
								TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
	}

	u8 *Dram1BufferPtr =
			Dram0BufferPtrs[MODEL_DRAM0_BUFFER_NUMBER - 1]
					+ ALIGN(
							TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
	u8 *ProgBufferPtr =
			Dram1BufferPtr
					+ ALIGN(
							TENSIL_ARCHITECTURE_DRAM1_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));

	XAxiDma_Config *AcqCfgPtr = XAxiDma_LookupConfig(
			XPAR_ACQUISITION_AXI_DMA_0_DEVICE_ID);
	Status = XAxiDma_CfgInitialize(&AcqAxiDma, AcqCfgPtr);

	if (Status)
		goto error;

	XGpio_WriteReg(XPAR_GPIO_0_BASEADDR, XGPIO_DATA_OFFSET, 0x1);

	XAxiDma_Config *RfftCfgPtr = XAxiDma_LookupConfig(
			XPAR_RFFT_AXI_DMA_0_DEVICE_ID);
	Status = XAxiDma_CfgInitialize(&RfftAxiDma, RfftCfgPtr);

	if (Status)
		goto error;

	XAxiDma_BdRing *RxRingPtr = XAxiDma_GetRxRing(&RfftAxiDma);
	XAxiDma_BdRing *TxRingPtr = XAxiDma_GetTxRing(&RfftAxiDma);

	XAxiDma_BdRingIntDisable(RxRingPtr, XAXIDMA_IRQ_ALL_MASK);
	XAxiDma_BdRingIntDisable(TxRingPtr, XAXIDMA_IRQ_ALL_MASK);

	XAxiDma_BdRingSetCoalesce(RxRingPtr, 1, 0);
	XAxiDma_BdRingSetCoalesce(TxRingPtr, 1, 0);

	Status = XAxiDma_BdRingCreate(RxRingPtr, (UINTPTR) RxBdSpace,
			(UINTPTR) RxBdSpace, XAXIDMA_BD_MINIMUM_ALIGNMENT, 1);

	if (Status)
		goto error;

	Status = XAxiDma_BdRingCreate(TxRingPtr, (UINTPTR) TxBdSpace,
			(UINTPTR) TxBdSpace, XAXIDMA_BD_MINIMUM_ALIGNMENT, 2);

	if (Status)
		goto error;

	XAxiDma_Bd BdTemplate;
	XAxiDma_BdClear(&BdTemplate);

	Status = XAxiDma_BdRingClone(RxRingPtr, &BdTemplate);

	if (Status)
		goto error;

	Status = XAxiDma_BdRingClone(TxRingPtr, &BdTemplate);

	if (Status)
		goto error;

	Status = XAxiDma_BdRingStart(RxRingPtr);

	if (Status)
		goto error;

	Status = XAxiDma_BdRingStart(TxRingPtr);

	if (Status)
		goto error;

	memset((void *) AcqBufferPtr, 0, ACQ_PACKET_DOUBLE_SIZE);
	memset((void *) RfftTxBufferPtr, 0, RFFT_TX_PACKET_SIZE);
	memset((void *) RfftRxBufferPtr, 0, RFFT_TX_FRAME_SIZE);

	const char *commands[] = { "stop", "go", "left", "right" };

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

	struct instruction_buffer buffer = { .ptr = ProgBufferPtr, .size = 0x100000,
			.offset = 0 };
	buffer_reset(&buffer);

	error = buffer_append_config_instruction(&buffer, &layout,
			CONFIG_REGISTER_DRAM0_OFFSET, 0);

	if (error)
		goto error;

	error = buffer_append_config_instruction(&buffer, &layout,
			CONFIG_REGISTER_DRAM1_OFFSET, CONFIG_DRAM_OFFSET(Dram1BufferPtr));

	if (error)
		goto error;

	error = buffer_append_config_instruction(&buffer, &layout,
	CONFIG_REGISTER_TIMEOUT, 100);

	if (error)
		goto error;

	memcpy((void *) Dram1BufferPtr,
			(const void*) MODEL_CONST_BASE,
			MODEL_CONST_SIZE_VECTORS * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));

	//Xil_DCacheFlushRange((UINTPTR)Dram0BufferPtr, TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
	//Xil_DCacheFlushRange((UINTPTR)Dram1BufferPtr, TENSIL_ARCHITECTURE_DRAM1_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));

	error = buffer_append_program(&buffer,
			(const u8*) MODEL_PROG_BASE, MODEL_PROG_SIZE);

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

	print("Init done\r\n");

	int acq_reversed = 0;
	int rfft_line = 0;

	size_t instructions_run_offset = 0;

	while (1) {
		size_t acq_offset = (1 - acq_reversed) * ACQ_PACKET_SIZE;

		Status = XAxiDma_SimpleTransfer(&AcqAxiDma,
				(UINTPTR) (AcqBufferPtr + acq_offset),
				ACQ_PACKET_SIZE, XAXIDMA_DEVICE_TO_DMA);

		if (Status)
			goto error;

		acq_reversed = (acq_reversed + 1) % 2;
		acq_offset = (1 - acq_reversed) * ACQ_PACKET_SIZE;

		memcpy((void*) (RfftTxBufferPtr + acq_offset),
				(const void*) (AcqBufferPtr + acq_offset),
				ACQ_PACKET_SIZE);

		XAxiDma_Bd *TxBdHeadPtr;
		Status = XAxiDma_BdRingAlloc(TxRingPtr, 2, &TxBdHeadPtr);

		if (Status)
			goto error;

		XAxiDma_Bd *TxBdPtr = TxBdHeadPtr;
		for (size_t i = 0; i < 2; i++) {
			size_t tx_offset = abs(i - acq_reversed) * ACQ_PACKET_SIZE;

			Status = XAxiDma_BdSetBufAddr(TxBdPtr,
					(UINTPTR) (RfftTxBufferPtr + tx_offset));

			if (Status)
				goto error;

			Status = XAxiDma_BdSetLength(TxBdPtr, ACQ_PACKET_SIZE,
					TxRingPtr->MaxTransferLen);

			if (Status)
				goto error;

			XAxiDma_BdSetCtrl(TxBdPtr,
					i ? XAXIDMA_BD_CTRL_TXEOF_MASK : XAXIDMA_BD_CTRL_TXSOF_MASK);
			XAxiDma_BdSetId(TxBdPtr, i);

			TxBdPtr = (XAxiDma_Bd *) XAxiDma_BdRingNext(TxRingPtr, TxBdPtr);
		}

		Status = XAxiDma_BdRingToHw(TxRingPtr, 2, TxBdHeadPtr);

		if (Status)
			goto error;

		XAxiDma_Bd *RxBdHeadPtr;
		Status = XAxiDma_BdRingAlloc(RxRingPtr, 1, &RxBdHeadPtr);

		if (Status)
			goto error;

		XAxiDma_Bd *RxBdPtr = RxBdHeadPtr;

		Status = XAxiDma_BdSetBufAddr(RxBdPtr,
				(UINTPTR) (RfftRxBufferPtr + rfft_line * RFFT_TX_FRAME_LINE_SIZE));

		if (Status)
			goto error;

		Status = XAxiDma_BdSetLength(RxBdPtr, RFFT_TX_FRAME_LINE_SIZE,
				RxRingPtr->MaxTransferLen);

		if (Status)
			goto error;

		XAxiDma_BdSetCtrl(RxBdPtr, 0);
		XAxiDma_BdSetId(RxBdPtr, 0);

		Status = XAxiDma_BdRingToHw(RxRingPtr, 1, RxBdHeadPtr);

		if (Status)
			goto error;

		while (XAxiDma_BdRingFromHw(RxRingPtr, XAXIDMA_ALL_BDS, &RxBdHeadPtr)
				!= 1
				|| XAxiDma_BdRingFromHw(TxRingPtr, XAXIDMA_ALL_BDS,
						&TxBdHeadPtr) != 2)
			;

		Status = XAxiDma_BdRingFree(TxRingPtr, 2, TxBdHeadPtr);

		if (Status)
			goto error;

		Status = XAxiDma_BdRingFree(RxRingPtr, 1, RxBdHeadPtr);

		if (Status)
			goto error;

		size_t prepare_index = rfft_line / MODEL_INPUT_STEP;
		size_t infer_index = prepare_index ? prepare_index - 1 : MODEL_DRAM0_BUFFER_NUMBER - 1;

		u8 *Dram0PrepareBufferPtr = Dram0BufferPtrs[prepare_index];
		u8 *Dram0InferBufferPtr = Dram0BufferPtrs[infer_index];

		for (size_t i = 0; i < MODEL_DRAM0_BUFFER_NUMBER; i++) {
			int shifted_line = rfft_line - i * MODEL_INPUT_STEP;

			size_t rfft_source_line = shifted_line < 0 ? RFFT_TX_FRAME_HEIGHT + shifted_line : shifted_line;
			size_t model_dest_line = (rfft_line % MODEL_INPUT_STEP) + (MODEL_DRAM0_BUFFER_NUMBER - 1 - i) * MODEL_INPUT_STEP;

			u8 *RfftRxBasePtr = RfftRxBufferPtr + rfft_source_line * RFFT_TX_FRAME_LINE_SIZE;
			u8 *Dram0BasePtr = Dram0PrepareBufferPtr + model_dest_line * MODEL_INPUT_LINE_SIZE;

			memset((void*) Dram0BasePtr, 0, MODEL_INPUT_LINE_SIZE);

			for (size_t j = 0; j < MODEL_INPUT_WIDTH; j++) {
				((MODEL_DT *) Dram0BasePtr)[j * MODEL_VECTOR_LENGTH] =
						((MODEL_DT *) RfftRxBasePtr)[RFFT_TX_FRAME_WIDTH - (j + 1)];
			}
		}

		rfft_line = (rfft_line + 1) % RFFT_TX_FRAME_HEIGHT;

		prepare_index = rfft_line / MODEL_INPUT_STEP;
		infer_index = prepare_index ? prepare_index - 1 : MODEL_DRAM0_BUFFER_NUMBER - 1;

		Dram0PrepareBufferPtr = Dram0BufferPtrs[prepare_index];
		Dram0InferBufferPtr = Dram0BufferPtrs[infer_index];

		if (rfft_line % MODEL_INPUT_STEP == 0) {
			if (instructions_run_offset)
				goto error;
			// Inference took longer than 500ms

			size_t buffer_offset = buffer.offset;
			buffer.offset = 0;

			error = buffer_append_config_instruction(&buffer, &layout,
					CONFIG_REGISTER_DRAM0_OFFSET,
					CONFIG_DRAM_OFFSET(Dram0InferBufferPtr));

			buffer.offset = buffer_offset;

			dram_fill_scalars(Dram0InferBufferPtr, arch.data_type,
					(TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1) * arch.array_size, 0,
					arch.array_size);

			dram_fill_scalars(Dram0InferBufferPtr, arch.data_type,
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
					if (dram_compare_scalars(Dram0InferBufferPtr,
							arch.data_type,
							(TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1)
									* arch.array_size,
							(TENSIL_ARCHITECTURE_DRAM0_DEPTH - 2)
									* arch.array_size, arch.array_size) == 0) {

						MODEL_DT max = 0;
						MODEL_DT max2 = 0;
						size_t i = argmax(4, (MODEL_DT*) Dram0InferBufferPtr, &max, &max2);

						if ((max - max2) > 32 * 256) {
							xil_printf("%s = %d (%d)\r\n", commands[i], max, max2);
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

		while (XAxiDma_Busy(&AcqAxiDma, XAXIDMA_DEVICE_TO_DMA))
			;

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

	//XTmrCtr_Reset(&Timer, 0);
	//XTmrCtr_Start(&Timer, 0);

	//XTmrCtr_Stop(&Timer, 0);
	//xil_printf("CYCLES: %d\r\n",  XTmrCtr_GetValue(&Timer, 0));

	error: cleanup_platform();
	return 0;
}
