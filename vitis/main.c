/******************************************************************************
 *
 * Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Use of the Software is limited solely to applications:
 * (a) running on a Xilinx device, or
 * (b) that interact with a Xilinx device through a bus or interconnect.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Xilinx shall not be used
 * in advertising or otherwise to promote the sale, use or other dealings in
 * this Software without prior written authorization from Xilinx.
 *
 ******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include <stdlib.h>
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

void print_float(float f) {
	if (f < 0.0)
		print("-");

	int integer = abs((int) f);
	int fraction = abs((int) ((f - (float) integer) * 1e6));
	xil_printf("%d.%06d", integer, fraction);
}

#define ACQ_PACKET_SAMPLES 256
#define ACQ_PACKET_SIZE (ACQ_PACKET_SAMPLES * sizeof(float))
#define ACQ_PACKET_HALF_SIZE (ACQ_PACKET_SIZE / 2)

#define RFFT_PACKET_VALUES ACQ_PACKET_SAMPLES
#define RFFT_PACKET_SIZE (RFFT_PACKET_VALUES * sizeof(short))
#define RFFT_FRAME_PACKETS 124
#define RFFT_FRAME_HALF_PACKETS (RFFT_FRAME_PACKETS / 2)
#define RFFT_FRAME_SIZE (RFFT_FRAME_PACKETS * RFFT_PACKET_SIZE)

#define SPEECH_MODEL_INPUT_WIDTH 129
#define SPEECH_MODEL_VECTOR_VALUES TENSIL_ARCHITECTURE_ARRAY_SIZE
#define SPEECH_MODEL_INPUT_VECTOR_SIZE (SPEECH_MODEL_VECTOR_VALUES * sizeof(short))
#define SPEECH_MODEL_INPUT_LINE_SIZE (SPEECH_MODEL_INPUT_WIDTH * SPEECH_MODEL_INPUT_VECTOR_SIZE)
#define SPEECH_MODEL_INPUT_HEIGHT RFFT_FRAME_PACKETS
#define SPEECH_MODEL_INPUT_SIZE (SPEECH_MODEL_INPUT_HEIGHT * SPEECH_MODEL_INPUT_LINE_SIZE)

#define ALIGNMENT 0x10000
#define ALIGN(s) (s / ALIGNMENT + 1) * ALIGNMENT

#define START ((u8 *) XPAR_MIG7SERIES_0_BASEADDR + 0x100000)

static size_t argmax(size_t size, const short *buffer) {
	if (!size)
		return -1;

	short max = buffer[0];
	size_t max_i = 0;

	for (size_t i = 1; i < size; i++)
		if (buffer[i] > max) {
			max = buffer[i];
			max_i = i;
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
	u8 *RfftTxBufferPtr = AcqBufferPtr + ALIGN(ACQ_PACKET_SIZE);
	u8 *RfftRxBufferPtr = RfftTxBufferPtr + ALIGN(ACQ_PACKET_SIZE);
	u8 *Dram0ABufferPtr = RfftRxBufferPtr + ALIGN(RFFT_FRAME_SIZE);
	u8 *Dram0BBufferPtr =
			Dram0ABufferPtr
					+ ALIGN(
							TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(short));
	u8 *Dram1BufferPtr =
			Dram0BBufferPtr
					+ ALIGN(
							TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(short));
	u8 *ProgBufferPtr =
			Dram1BufferPtr
					+ ALIGN(
							TENSIL_ARCHITECTURE_DRAM1_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(short));
	u8 *Dram0PrepareBufferPtr = Dram0ABufferPtr;
	u8 *Dram0InferBufferPtr = Dram0BBufferPtr;

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

	memset((void *) AcqBufferPtr, 0, ACQ_PACKET_SIZE);
	memset((void *) RfftTxBufferPtr, 0, ACQ_PACKET_SIZE);
	memset((void *) RfftRxBufferPtr, 0, RFFT_FRAME_SIZE);

	const char *commands[] = { "stop", "down", "yes", "go", "left", "right",
			"up", "no" };

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
			(const void*) (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + 0x500000),
			93808 * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(short));

	//Xil_DCacheFlushRange((UINTPTR)Dram0BufferPtr, TENSIL_ARCHITECTURE_DRAM0_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(short));
	//Xil_DCacheFlushRange((UINTPTR)Dram1BufferPtr, TENSIL_ARCHITECTURE_DRAM1_DEPTH * TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(short));

	error = buffer_append_program(&buffer,
			(const u8*) (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + 0x400000), 642064);

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

	int acq_reversed = 0;
	int stft_packet = 0;

	size_t instructions_run_offset = 0;

	while (1) {
		size_t acq_offset = (1 - acq_reversed) * ACQ_PACKET_HALF_SIZE;

		Status = XAxiDma_SimpleTransfer(&AcqAxiDma,
				(UINTPTR) (AcqBufferPtr + acq_offset),
				ACQ_PACKET_HALF_SIZE, XAXIDMA_DEVICE_TO_DMA);

		if (Status)
			goto error;

		acq_reversed = (acq_reversed + 1) % 2;
		acq_offset = (1 - acq_reversed) * ACQ_PACKET_HALF_SIZE;

		memcpy((void*) (RfftTxBufferPtr + acq_offset),
				(const void*) (AcqBufferPtr + acq_offset),
				ACQ_PACKET_HALF_SIZE);

		XAxiDma_Bd *TxBdHeadPtr;
		Status = XAxiDma_BdRingAlloc(TxRingPtr, 2, &TxBdHeadPtr);

		if (Status)
			goto error;

		XAxiDma_Bd *TxBdPtr = TxBdHeadPtr;
		for (size_t i = 0; i < 2; i++) {
			size_t tx_offset = abs(i - acq_reversed) * ACQ_PACKET_HALF_SIZE;

			Status = XAxiDma_BdSetBufAddr(TxBdPtr,
					(UINTPTR) (RfftTxBufferPtr + tx_offset));

			if (Status)
				goto error;

			Status = XAxiDma_BdSetLength(TxBdPtr, ACQ_PACKET_HALF_SIZE,
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
				(UINTPTR) (RfftRxBufferPtr + stft_packet * RFFT_PACKET_SIZE));

		if (Status)
			goto error;

		Status = XAxiDma_BdSetLength(RxBdPtr, RFFT_PACKET_SIZE,
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

		if (stft_packet < RFFT_FRAME_HALF_PACKETS) {
			u8 *Dram0BasePtr = Dram0PrepareBufferPtr
					+ (stft_packet + RFFT_FRAME_HALF_PACKETS)
							* SPEECH_MODEL_INPUT_LINE_SIZE;
			u8 *RfftRxBasePtr = RfftRxBufferPtr + stft_packet * RFFT_PACKET_SIZE;

			memset((void*) Dram0BasePtr, 0, SPEECH_MODEL_INPUT_LINE_SIZE);

			for (size_t i = 0; i < SPEECH_MODEL_INPUT_WIDTH; i++) {
				((short *) Dram0BasePtr)[i * SPEECH_MODEL_VECTOR_VALUES] =
						((short *) RfftRxBasePtr)[RFFT_PACKET_VALUES - (i + 1)];
			}

			Dram0BasePtr = Dram0PrepareBufferPtr
					+ stft_packet * SPEECH_MODEL_INPUT_LINE_SIZE;
			RfftRxBasePtr =
					RfftRxBufferPtr
							+ (stft_packet + RFFT_FRAME_HALF_PACKETS)
									* RFFT_PACKET_SIZE;

			memset((void*) Dram0BasePtr, 0, SPEECH_MODEL_INPUT_LINE_SIZE);

			for (size_t i = 0; i < SPEECH_MODEL_INPUT_WIDTH; i++) {
				((short *) Dram0BasePtr)[i * SPEECH_MODEL_VECTOR_VALUES] =
						((short *) RfftRxBasePtr)[RFFT_PACKET_VALUES - (i + 1)];
			}
		} else {
			u8 *Dram0BasePtr = Dram0PrepareBufferPtr
					+ stft_packet * SPEECH_MODEL_INPUT_LINE_SIZE;
			u8 *RfftRxBasePtr = RfftRxBufferPtr + stft_packet * RFFT_PACKET_SIZE;

			memset((void*) Dram0BasePtr, 0, SPEECH_MODEL_INPUT_LINE_SIZE);

			for (size_t i = 0; i < SPEECH_MODEL_INPUT_WIDTH; i++) {
				((short *) Dram0BasePtr)[i * SPEECH_MODEL_VECTOR_VALUES] =
						((short *) RfftRxBasePtr)[RFFT_PACKET_VALUES - (i + 1)];
			}

			Dram0BasePtr = Dram0PrepareBufferPtr
					+ (stft_packet - RFFT_FRAME_HALF_PACKETS)
							* SPEECH_MODEL_INPUT_LINE_SIZE;
			RfftRxBasePtr =
					RfftRxBufferPtr
							+ (stft_packet - RFFT_FRAME_HALF_PACKETS)
									* RFFT_PACKET_SIZE;

			memset((void*) Dram0BasePtr, 0, SPEECH_MODEL_INPUT_LINE_SIZE);

			for (size_t i = 0; i < SPEECH_MODEL_INPUT_WIDTH; i++) {
				((short *) Dram0BasePtr)[i * SPEECH_MODEL_VECTOR_VALUES] =
						((short *) RfftRxBasePtr)[RFFT_PACKET_VALUES - (i + 1)];
			}
		}

		stft_packet = (stft_packet + 1) % RFFT_FRAME_PACKETS;

		if (stft_packet == 0 || stft_packet == RFFT_FRAME_HALF_PACKETS) {
			if (instructions_run_offset)
				goto error;
			// Inference took longer than 500ms

			u8 *Tmp = Dram0PrepareBufferPtr;
			Dram0PrepareBufferPtr = Dram0InferBufferPtr;
			Dram0InferBufferPtr = Tmp;

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

						size_t i = argmax(8, (short*) Dram0InferBufferPtr);
						float max = (float) ((short*) Dram0InferBufferPtr)[i]
								/ 256.0;

						if (max > 50.0) {
							xil_printf("%s = ", commands[i]);
							print_float(max);
							xil_printf("\r\n");
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

	/*for (size_t i = 0; i < SPEECH_MODEL_INPUT_HEIGHT; i++)
	 for (size_t j = 0; j < SPEECH_MODEL_INPUT_WIDTH; j++)
	 for (size_t k = 0; k < SPEECH_MODEL_VECTOR_VALUES; k++) {
	 print_float((float)((short*) Dram0BufferPtr)[(i * SPEECH_MODEL_INPUT_WIDTH + j) * SPEECH_MODEL_VECTOR_VALUES + k] / 256.0);

	 if (k == SPEECH_MODEL_VECTOR_VALUES - 1)
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
