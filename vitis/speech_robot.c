/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright © 2019-2022 Tensil AI Company */

#include "platform.h"
#include "xaxidma.h"
#include "xgpio_l.h"
#include "xil_printf.h"
#include "xtmrctr.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "architecture_params.h"
#include "tensil/architecture.h"
#include "tensil/dram.h"
#include "tensil/error.h"
#include "tensil/instruction.h"
#include "tensil/instruction_buffer.h"
#include "tensil/tcu.h"

/*
 * Definitions for packet and frame shapes are derived from the
 * speech commands ML model architecture.
 *
 * https://github.com/petrohi/speech-robot/blob/main/model/speech_commands.ipynb
 */

#define ACQ_DT float

#define ACQ_PACKET_LENGTH 128
#define ACQ_PACKET_SIZE (ACQ_PACKET_LENGTH * sizeof(ACQ_DT))
#define ACQ_PACKET_DOUBLE_SIZE (2 * ACQ_PACKET_SIZE)

#define RFFT_TX_PACKET_SIZE ACQ_PACKET_DOUBLE_SIZE

#define RFFT_RX_FRAME_WIDTH (2 * ACQ_PACKET_LENGTH)
#define RFFT_RX_FRAME_LINE_SIZE (RFFT_RX_FRAME_WIDTH * sizeof(MODEL_DT))
#define RFFT_RX_FRAME_HEIGHT 124
#define RFFT_RX_FRAME_SIZE (RFFT_RX_FRAME_HEIGHT * RFFT_RX_FRAME_LINE_SIZE)

#define MODEL_DT int16_t
#define MODEL_DT_MIN INT16_MIN

#define MODEL_VECTOR_LENGTH TENSIL_ARCHITECTURE_ARRAY_SIZE
#define MODEL_VECTOR_SIZE (MODEL_VECTOR_LENGTH * sizeof(MODEL_DT))

#define MODEL_INPUT_WINDOW_NUMBER 4

#define MODEL_INPUT_WIDTH (RFFT_RX_FRAME_WIDTH / 2 + 1)
#define MODEL_INPUT_LINE_SIZE (MODEL_INPUT_WIDTH * MODEL_VECTOR_SIZE)
#define MODEL_INPUT_HEIGHT RFFT_RX_FRAME_HEIGHT
#define MODEL_INPUT_STEP (MODEL_INPUT_HEIGHT / MODEL_INPUT_WINDOW_NUMBER)
#define MODEL_INPUT_SIZE (MODEL_INPUT_HEIGHT * MODEL_INPUT_LINE_SIZE)

#define MODEL_OUTPUT_LENGTH 12

/*
 * We place the artifacts produced by `tensil compile` tool
 * in flash image following the FPGA bitstream. The flash offsets
 * for program and consts are determined by sizes of bitstream and
 * program correspondingly to allow for compact flash image.
 *
 * Program is the content of speech_commands_onnx_speech_robot.tprog file.
 *
 * Const is the content of speech_commands_onnx_speech_robot.tdata file.
 *
 * Flash sizes are set from `prog.size` and `consts[0].size` in
 * speech_commands_onnx_speech_robot.tmodel file.
 */

#define MODEL_FLASH_PROG_OFFSET 0x400000
#define MODEL_FLASH_PROG_BASE                                                  \
    (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + MODEL_FLASH_PROG_OFFSET)
#define MODEL_FLASH_PROG_SIZE 642464

#define MODEL_FLASH_CONST_OFFSET 0x500000
#define MODEL_FLASH_CONST_BASE                                                 \
    (XPAR_AXI_QUAD_SPI_0_AXI4_BASEADDR + MODEL_FLASH_CONST_OFFSET)
#define MODEL_FLASH_CONST_SIZE_VECTORS 93937
#define MODEL_FLASH_CONST_SIZE                                                 \
    (MODEL_FLASH_CONST_SIZE_VECTORS * TENSIL_ARCHITECTURE_ARRAY_SIZE *         \
     sizeof(MODEL_DT))

#define EXP_DT double

#define EXP_TX_PACKET_SIZE (MODEL_OUTPUT_LENGTH * sizeof(MODEL_DT))
#define EXP_RX_PACKET_SIZE (MODEL_OUTPUT_LENGTH * sizeof(EXP_DT))

#define BUFFER_ALIGNMENT 0x10000
#define BUFFER_ALIGN(s) (s / BUFFER_ALIGNMENT + 1) * BUFFER_ALIGNMENT
#define BUFFER_START ((u8 *)XPAR_MIG7SERIES_0_BASEADDR)

#define TENSIL_INSTRUCTION_BUFFER_SIZE 0x100000

static void print_float(EXP_DT f) {
    if (f < 0.0)
        print("-");

    int integer = abs((int)f);
    int fraction = abs((int)((f - (double)integer) * 1e9));
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

const char *commands[MODEL_OUTPUT_LENGTH] = {
    "down",  "go",   "left", "no",  "off",       "on",
    "right", "stop", "up",   "yes", "_silence_", "_unknown_"};

int main() {
    init_platform();

    tensil_error_t error = TENSIL_ERROR_NONE;

    TENSIL_XILINX_RESULT_FRAME

    error = TENSIL_XILINX_RESULT(
        XTmrCtr_Initialize(&tmr_ctr, XPAR_TMRCTR_0_DEVICE_ID));

    if (error)
        goto error;

    /*
     * Initialize various buffers in DDR.
     */

    u8 *rfft_rx_bd_space = BUFFER_START;
    u8 *rfft_tx_bd_space =
        rfft_rx_bd_space +
        BUFFER_ALIGN(XAxiDma_BdRingMemCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, 1));

    u8 *acq_buffer_ptr =
        rfft_tx_bd_space +
        BUFFER_ALIGN(XAxiDma_BdRingMemCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, 2));
    u8 *rfft_tx_buffer_ptr =
        acq_buffer_ptr + BUFFER_ALIGN(ACQ_PACKET_DOUBLE_SIZE);
    u8 *rfft_rx_buffer_ptr =
        rfft_tx_buffer_ptr + BUFFER_ALIGN(RFFT_TX_PACKET_SIZE);

    u8 *drma0_buffer_ptrs[2];

    drma0_buffer_ptrs[0] =
        rfft_rx_buffer_ptr + BUFFER_ALIGN(RFFT_RX_FRAME_SIZE);

    for (size_t i = 1; i < 2; i++) {
        drma0_buffer_ptrs[i] =
            drma0_buffer_ptrs[i - 1] +
            BUFFER_ALIGN(TENSIL_ARCHITECTURE_DRAM0_DEPTH *
                         TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
    }

    u8 *dram1_buffer_ptr =
        drma0_buffer_ptrs[1] +
        BUFFER_ALIGN(TENSIL_ARCHITECTURE_DRAM0_DEPTH *
                     TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));
    u8 *prog_buffer_ptr =
        dram1_buffer_ptr +
        BUFFER_ALIGN(TENSIL_ARCHITECTURE_DRAM1_DEPTH *
                     TENSIL_ARCHITECTURE_ARRAY_SIZE * sizeof(MODEL_DT));

    u8 *exp_rx_buffer_ptr =
        prog_buffer_ptr + BUFFER_ALIGN(TENSIL_INSTRUCTION_BUFFER_SIZE);

    /*
     * Initialize acquisition DMA.
     */

    XAxiDma_Config *acq_cfg_ptr =
        XAxiDma_LookupConfig(XPAR_ACQUISITION_AXI_DMA_0_DEVICE_ID);
    error =
        TENSIL_XILINX_RESULT(XAxiDma_CfgInitialize(&acq_axi_dma, acq_cfg_ptr));

    if (error)
        goto error;

    /*
     * Once acquisition DMA is initialize we can release microhone SPI
     * from reset. Otherwise the sporadic ready signals sent by Xilinx
     * AXI DMA will upset SPI packet counter.
     */

    XGpio_WriteReg(XPAR_GPIO_0_BASEADDR, XGPIO_DATA_OFFSET, 0x1);

    /*
     * Initialize RFFT scatter-gather DMA.
     */

    XAxiDma_Config *rfft_cfg_ptr =
        XAxiDma_LookupConfig(XPAR_RFFT_AXI_DMA_0_DEVICE_ID);
    error = TENSIL_XILINX_RESULT(
        XAxiDma_CfgInitialize(&rfft_axi_dma, rfft_cfg_ptr));

    if (error)
        goto error;

    XAxiDma_BdRing *rfft_rx_ring_ptr = XAxiDma_GetRxRing(&rfft_axi_dma);
    XAxiDma_BdRing *rfft_tx_ring_ptr = XAxiDma_GetTxRing(&rfft_axi_dma);

    XAxiDma_BdRingIntDisable(rfft_rx_ring_ptr, XAXIDMA_IRQ_ALL_MASK);
    XAxiDma_BdRingIntDisable(rfft_tx_ring_ptr, XAXIDMA_IRQ_ALL_MASK);

    XAxiDma_BdRingSetCoalesce(rfft_rx_ring_ptr, 1, 0);
    XAxiDma_BdRingSetCoalesce(rfft_tx_ring_ptr, 1, 0);

    error = TENSIL_XILINX_RESULT(XAxiDma_BdRingCreate(
        rfft_rx_ring_ptr, (UINTPTR)rfft_rx_bd_space, (UINTPTR)rfft_rx_bd_space,
        XAXIDMA_BD_MINIMUM_ALIGNMENT, 1));

    if (error)
        goto error;

    error = TENSIL_XILINX_RESULT(XAxiDma_BdRingCreate(
        rfft_tx_ring_ptr, (UINTPTR)rfft_tx_bd_space, (UINTPTR)rfft_tx_bd_space,
        XAXIDMA_BD_MINIMUM_ALIGNMENT, 2));

    if (error)
        goto error;

    XAxiDma_Bd bd_template;
    XAxiDma_BdClear(&bd_template);

    error = TENSIL_XILINX_RESULT(
        XAxiDma_BdRingClone(rfft_rx_ring_ptr, &bd_template));

    if (error)
        goto error;

    error = TENSIL_XILINX_RESULT(
        XAxiDma_BdRingClone(rfft_tx_ring_ptr, &bd_template));

    if (error)
        goto error;

    error = TENSIL_XILINX_RESULT(XAxiDma_BdRingStart(rfft_rx_ring_ptr));

    if (error)
        goto error;

    error = TENSIL_XILINX_RESULT(XAxiDma_BdRingStart(rfft_tx_ring_ptr));

    if (error)
        goto error;

    /*
     * Initialze buffers to zero since we will be using them while
     * not fully filled for sliding windows.
     */

    memset((void *)acq_buffer_ptr, 0, ACQ_PACKET_DOUBLE_SIZE);
    memset((void *)rfft_tx_buffer_ptr, 0, RFFT_TX_PACKET_SIZE);
    memset((void *)rfft_rx_buffer_ptr, 0, RFFT_RX_FRAME_SIZE);

    /*
     * TENSIL_ARCHITECTURE parameters come from architecture_params.h
     * created by `tensil rtl` tool based on architecture definition in
     * ./arch/speech_robot.tarch.
     */

    struct tensil_architecture arch = {
        .array_size = TENSIL_ARCHITECTURE_ARRAY_SIZE,
        .data_type = TENSIL_ARCHITECTURE_DATA_TYPE,
        .local_depth = TENSIL_ARCHITECTURE_LOCAL_DEPTH,
        .accumulator_depth = TENSIL_ARCHITECTURE_ACCUMULATOR_DEPTH,
        .dram0_depth = TENSIL_ARCHITECTURE_DRAM0_DEPTH,
        .dram1_depth = TENSIL_ARCHITECTURE_DRAM1_DEPTH,
        .stride0_depth = TENSIL_ARCHITECTURE_STRIDE0_DEPTH,
        .stride1_depth = TENSIL_ARCHITECTURE_STRIDE1_DEPTH,
        .simd_registers_depth = TENSIL_ARCHITECTURE_SIMD_REGISTERS_DEPTH,
    };

    if (!tensil_architecture_is_valid(&arch))
        goto error;

    struct tensil_instruction_layout layout;

    tensil_instruction_layout_init(&layout, &arch);

    struct tensil_compute_unit tcu;

    error = tensil_compute_unit_init(&tcu);

    if (error)
        goto error;

    struct tensil_instruction_buffer buffer = {
        .ptr = prog_buffer_ptr,
        .size = TENSIL_INSTRUCTION_BUFFER_SIZE,
        .offset = 0};

    tensil_buffer_reset(&buffer);

    /*
     * We start TCU program by configring DRAM0 and DRAM1 offsets.
     * Since we use multiple DRAM0 buffers, DRAM0 offset configuration
     * instruction is a placeholder with offset set to 0xffff. Before
     * running the program we will set this offset to real one by
     * overwriting this instruction.
     */

    error = tensil_buffer_append_config_instruction(
        &buffer, &layout, TENSIL_CONFIG_REGISTER_DRAM0_OFFSET, 0xffff);

    if (error)
        goto error;

    error = tensil_buffer_append_config_instruction(
        &buffer, &layout, TENSIL_CONFIG_REGISTER_DRAM1_OFFSET,
        TENSIL_CONFIG_DRAM_OFFSET(dram1_buffer_ptr));

    if (error)
        goto error;

    /*
     * Copy compiled TCU program from flash memory to the instruction
     * buffer in DDR. Since there is "preamble" and "postamble"
     * instructions that are not generated by the compiler we cannot
     * run the program as-is from flash memory.
     */

    error = tensil_buffer_append_program(
        &buffer, (const u8 *)MODEL_FLASH_PROG_BASE, MODEL_FLASH_PROG_SIZE);

    if (error)
        goto error;

    /*
     * In order to ensure that TCU program ran to its completion
     * we add a pair of data move instructions at the end of the
     * program to copy special "probe" vector from last location to
     * second to last location in DRAM0. We later will monitor DRAM0
     * for this change.
     */

    error = tensil_buffer_append_instruction(
        &buffer, &layout, TENSIL_OPCODE_DATA_MOVE,
        TENSIL_DATA_MOVE_FLAG_DRAM0_TO_LOCAL, 0,
        TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1, 0);

    if (error)
        goto error;

    error = tensil_buffer_append_instruction(
        &buffer, &layout, TENSIL_OPCODE_DATA_MOVE,
        TENSIL_DATA_MOVE_FLAG_LOCAL_TO_DRAM0, 0,
        TENSIL_ARCHITECTURE_DRAM0_DEPTH - 2, 0);

    if (error)
        goto error;

    error = tensil_buffer_pad_to_alignment(
        &buffer, &layout,
        tensil_compute_unit_get_instructions_data_width_bytes(&tcu));

    if (error)
        goto error;

    /*
     * Copy ML model constants (weights) from flash memory to DDR. If there
     * is insufficient amount of DDR memory the TCU could read directly from
     * flash address space with corresponding changes in Vivado design Address
     * Editor.
     */

    memcpy((void *)dram1_buffer_ptr, (const void *)MODEL_FLASH_CONST_BASE,
           MODEL_FLASH_CONST_SIZE);

    XAxiDma_Config *exp_cfg_ptr =
        XAxiDma_LookupConfig(XPAR_EXP_AXI_DMA_0_DEVICE_ID);
    error =
        TENSIL_XILINX_RESULT(XAxiDma_CfgInitialize(&exp_axi_dma, exp_cfg_ptr));

    if (error)
        goto error;

    print("Ready!\r\n");

    int acq_reversed = 0;
    int rfft_line = 0;

    size_t instructions_run_offset = 0;

    /* The main loop starts with initiating DMA transfer of
     * of acqisition packet and ends with waiting for it to
     * complete. At 16Hz sampling rate it takes 8ms to acquire
     * 128 samples. Therefore, everything that happens between
     * initiating the transfer and its wait loop must take less
     * than 8ms. Otherwise samples will be dropped.
     */

    while (true) {

        /*
         * Acquisition uses double-buffering to allow DMA transfer
         * of acqisition packet to proceed into one half of the buffer
         * while the other half is available for copying to RFFT TX buffer.
         */

        size_t acq_offset = (1 - acq_reversed) * ACQ_PACKET_SIZE;

        error = TENSIL_XILINX_RESULT(XAxiDma_SimpleTransfer(
            &acq_axi_dma, (UINTPTR)(acq_buffer_ptr + acq_offset),
            ACQ_PACKET_SIZE, XAXIDMA_DEVICE_TO_DMA));

        if (error)
            goto error;

        acq_reversed = (acq_reversed + 1) % 2;
        acq_offset = (1 - acq_reversed) * ACQ_PACKET_SIZE;

        memcpy((void *)(rfft_tx_buffer_ptr + acq_offset),
               (const void *)(acq_buffer_ptr + acq_offset), ACQ_PACKET_SIZE);

        /*
         * Each RFFT TX packet is comprised of two acqisition packet to
         * represent a sliding window over acqisition samples. This sliding
         * window is required to produce STFT, which we will call a spectogram.
         *
         * https://en.wikipedia.org/wiki/Short-time_Fourier_transform
         *
         * Because we minimize copying the RFFT TX packet halves are
         * alternated between natural and reverse order. To accomodate
         * this we use scatter-gather DMA with RFFT. Transfer side (TX)
         * uses two DMA blocks, each mapping into RFFT TX packet halves
         * in their current order. Receiving side (RX) uses one block to
         * place resulting RFFT RX line into RFFT RX frame. This frame height
         * is defined by the model input dimentions, which is 124 so that
         * each frame represents 1 second spectogram at 16Hz sample rate.
         */

        XAxiDma_Bd *rfft_rx_bd_head_ptr;
        error = TENSIL_XILINX_RESULT(
            XAxiDma_BdRingAlloc(rfft_tx_ring_ptr, 2, &rfft_rx_bd_head_ptr));

        if (error)
            goto error;

        XAxiDma_Bd *cur_bd_ptr = rfft_rx_bd_head_ptr;
        for (size_t i = 0; i < 2; i++) {
            size_t tx_offset = abs(i - acq_reversed) * ACQ_PACKET_SIZE;

            error = TENSIL_XILINX_RESULT(XAxiDma_BdSetBufAddr(
                cur_bd_ptr, (UINTPTR)(rfft_tx_buffer_ptr + tx_offset)));

            if (error)
                goto error;

            error = TENSIL_XILINX_RESULT(XAxiDma_BdSetLength(
                cur_bd_ptr, ACQ_PACKET_SIZE, rfft_tx_ring_ptr->MaxTransferLen));

            if (error)
                goto error;

            XAxiDma_BdSetCtrl(cur_bd_ptr, i ? XAXIDMA_BD_CTRL_TXEOF_MASK
                                            : XAXIDMA_BD_CTRL_TXSOF_MASK);
            XAxiDma_BdSetId(cur_bd_ptr, i);

            cur_bd_ptr =
                (XAxiDma_Bd *)XAxiDma_BdRingNext(rfft_tx_ring_ptr, cur_bd_ptr);
        }

        error = TENSIL_XILINX_RESULT(
            XAxiDma_BdRingToHw(rfft_tx_ring_ptr, 2, rfft_rx_bd_head_ptr));

        if (error)
            goto error;

        XAxiDma_Bd *rfft_rx_head_ptr;
        error = TENSIL_XILINX_RESULT(
            XAxiDma_BdRingAlloc(rfft_rx_ring_ptr, 1, &rfft_rx_head_ptr));

        if (error)
            goto error;

        cur_bd_ptr = rfft_rx_head_ptr;

        error = TENSIL_XILINX_RESULT(XAxiDma_BdSetBufAddr(
            cur_bd_ptr, (UINTPTR)(rfft_rx_buffer_ptr +
                                  rfft_line * RFFT_RX_FRAME_LINE_SIZE)));

        if (error)
            goto error;

        error = TENSIL_XILINX_RESULT(
            XAxiDma_BdSetLength(cur_bd_ptr, RFFT_RX_FRAME_LINE_SIZE,
                                rfft_rx_ring_ptr->MaxTransferLen));

        if (error)
            goto error;

        XAxiDma_BdSetCtrl(cur_bd_ptr, 0);
        XAxiDma_BdSetId(cur_bd_ptr, 0);

        error = TENSIL_XILINX_RESULT(
            XAxiDma_BdRingToHw(rfft_rx_ring_ptr, 1, rfft_rx_head_ptr));

        if (error)
            goto error;

        while (XAxiDma_BdRingFromHw(rfft_rx_ring_ptr, XAXIDMA_ALL_BDS,
                                    &rfft_rx_head_ptr) != 1 ||
               XAxiDma_BdRingFromHw(rfft_tx_ring_ptr, XAXIDMA_ALL_BDS,
                                    &rfft_rx_bd_head_ptr) != 2)
            ;

        error = TENSIL_XILINX_RESULT(
            XAxiDma_BdRingFree(rfft_tx_ring_ptr, 2, rfft_rx_bd_head_ptr));

        if (error)
            goto error;

        error = TENSIL_XILINX_RESULT(
            XAxiDma_BdRingFree(rfft_rx_ring_ptr, 1, rfft_rx_head_ptr));

        if (error)
            goto error;

        /*
         * To minimize the overhead of copying RFFT lines we setup double-
         * buffering with two DRAM0 buffers to serve alternatively as an
         * input to ML model. While one buffer is being prepared by copying
         * spectogram lines from RFFT RX buffer, the other one is being used
         * for running ML inference.
         *
         * The MODEL_INPUT_WINDOW_NUMBER determines how many windows are
         * being tracked over a 1 second long spectrogram. For example, if
         * this is set to 1 there will be an inference every second.
         *
         * This can be a problem if interesting spectrogram pattern occurs
         * at the edge, so that it is split between two inferences. When
         * MODEL_INPUT_WINDOW_NUMBER is set to 4, there will be an inference
         * every 250ms using a 1/4 of recent spectogram lines and a 3/4 of
         * lines that already been processed with previous inferences. The
         * limit to how many windows we can use is the latency of ML inference.
         */

        size_t prepare_index = (rfft_line / MODEL_INPUT_STEP) % 2;
        size_t infer_index = (prepare_index + 1) % 2;

        u8 *dram0_prepare_buffer_ptr = drma0_buffer_ptrs[prepare_index];
        u8 *dram0_infer_buffer_ptr = drma0_buffer_ptrs[infer_index];

        if (rfft_line % MODEL_INPUT_STEP == 0) {

            /*
             * If instructions_run_offset is non-zero the current inference
             * did not finish in time to start new inference.
             */

            if (instructions_run_offset)
                goto error;

            /*
             * New inference buffer is ready. We adjust the TCU program
             * in-place to set DRAM0 offset configuration. This configuration
             * instruction was written at offset 0 in initalization phase.
             * Thus, we temporarily set buffer.offset to 0, then we append
             * (overwite) the instruction, and restore buffer.offset to its
             * original value.
             */

            size_t buffer_offset = buffer.offset;
            buffer.offset = 0;

            error = tensil_buffer_append_config_instruction(
                &buffer, &layout, TENSIL_CONFIG_REGISTER_DRAM0_OFFSET,
                TENSIL_CONFIG_DRAM_OFFSET(dram0_infer_buffer_ptr));

            buffer.offset = buffer_offset;

            /*
             * Write "probe" vectors to DRAM0. Vectors need to be filled
             * with different byte values. Once the TCU performed the
             * copy at the end of the program, they will contain should be
             * the same.
             */

            tensil_dram_fill_bytes(dram0_infer_buffer_ptr, arch.data_type,
                                   (TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1) *
                                       arch.array_size,
                                   0, arch.array_size);

            tensil_dram_fill_bytes(dram0_infer_buffer_ptr, arch.data_type,
                                   (TENSIL_ARCHITECTURE_DRAM0_DEPTH - 2) *
                                       arch.array_size,
                                   0xff, arch.array_size);

            /*
             * Start running TCU program to perform the inference. This
             * will proceed concurrently with acqistion and RFFT processing
             * and may take multiple loop iterations to complete.
             */

            error = tensil_compute_unit_start_instructions(
                &tcu, &buffer, &instructions_run_offset);

            if (error)
                goto error;
        }

        if (instructions_run_offset) {

            /*
             * We are currently running the TCU program. Check if the current
             * block of TCU instructions has been processed. If so, check
             * of all instructions have been processed.
             */

            if (!tensil_compute_unit_is_instructions_busy(&tcu)) {
                if (instructions_run_offset == buffer.offset) {

                    /*
                     * The entire instruction buffer has been processed by
                     * the TCU. This does not mean that the program is fully
                     * completed since some instructions, like data moves,
                     * may continue to be "in-flight". To ensure the program
                     * completion we compare "probe" vectors that should be
                     * copied at the end of the program.
                     */

                    if (tensil_dram_compare_bytes(
                            dram0_infer_buffer_ptr, arch.data_type,
                            (TENSIL_ARCHITECTURE_DRAM0_DEPTH - 1) *
                                arch.array_size,
                            (TENSIL_ARCHITECTURE_DRAM0_DEPTH - 2) *
                                arch.array_size,
                            arch.array_size) == 0) {

                        /*
                         * The ML inference is complete. DRAM0 contains the
                         * predictions which can be used by argmax.
                         *
                         * But, in order to provide a better basis for
                         * confidence thresholding we perform softmax function.
                         * This function normalizes the output of the model to a
                         * probability distribution over predicted output
                         * classes.
                         *
                         * https://en.wikipedia.org/wiki/Softmax_function
                         *
                         * We use hardware acceleration to convert DRAM0 fixed
                         * point values to double precistion floating point, and
                         * then calculate the exponent function for each value.
                         * To do this we initiate the transfer (TX) from DRAM0
                         * and the receiving (RX) to exponent RX buffer.
                         */

                        error = TENSIL_XILINX_RESULT(XAxiDma_SimpleTransfer(
                            &exp_axi_dma, (UINTPTR)(dram0_infer_buffer_ptr),
                            EXP_TX_PACKET_SIZE, XAXIDMA_DMA_TO_DEVICE));

                        if (error)
                            goto error;

                        error = TENSIL_XILINX_RESULT(XAxiDma_SimpleTransfer(
                            &exp_axi_dma, (UINTPTR)(exp_rx_buffer_ptr),
                            EXP_RX_PACKET_SIZE, XAXIDMA_DEVICE_TO_DMA));

                        if (error)
                            goto error;

                        while (
                            XAxiDma_Busy(&exp_axi_dma, XAXIDMA_DEVICE_TO_DMA))
                            ;

                        EXP_DT softmax_buffer[MODEL_OUTPUT_LENGTH];
                        EXP_DT sum = 0;

                        /*
                         * We copy exponent RX buffer (DDR) to stack (BRAM)
                         * to make sure that further calculations are happening
                         * in the fast memory.
                         */

                        memcpy((void *)softmax_buffer,
                               (const void *)exp_rx_buffer_ptr,
                               EXP_RX_PACKET_SIZE);

                        for (size_t i = 0; i < MODEL_OUTPUT_LENGTH; i++)
                            sum += softmax_buffer[i];

                        for (size_t i = 0; i < MODEL_OUTPUT_LENGTH; i++)
                            softmax_buffer[i] = softmax_buffer[i] / sum;

                        EXP_DT max;
                        size_t max_i =
                            argmax(MODEL_OUTPUT_LENGTH, softmax_buffer, &max);

                        print_float(max);
                        print(" ");
                        print(commands[max_i]);

                        if (max > 0.9) {
                            print("<-------------\r\n");
                        } else
                            print("\r\n");

                        instructions_run_offset = 0;
                    }

                } else {
                    error = tensil_compute_unit_start_instructions(
                        &tcu, &buffer, &instructions_run_offset);

                    if (error)
                        goto error;
                }
            }
        }

        /*
         * Copy a spectrogram lines from RFFT RX buffer to DRAM0 prepare
         * buffer. Since copying the entire spectrogram frame would take
         * longer than main loop deadline, we schedule copying to be
         * distributed over its iterations.
         */

        for (size_t i = 0; i < MODEL_INPUT_WINDOW_NUMBER; i++) {
            int shifted_line = rfft_line - i * MODEL_INPUT_STEP;

            size_t rfft_source_line = shifted_line < 0
                                          ? RFFT_RX_FRAME_HEIGHT + shifted_line
                                          : shifted_line;
            size_t model_dest_line =
                (rfft_line % MODEL_INPUT_STEP) +
                (MODEL_INPUT_WINDOW_NUMBER - 1 - i) * MODEL_INPUT_STEP;

            u8 *rfft_rx_line_ptr =
                rfft_rx_buffer_ptr + rfft_source_line * RFFT_RX_FRAME_LINE_SIZE;
            u8 *dram0_line_ptr = dram0_prepare_buffer_ptr +
                                 model_dest_line * MODEL_INPUT_LINE_SIZE;

            /*
             * RFFT values appear in the "channel" dimension of ML model,
             * which needs to be aligned on TENSIL_ARCHITECTURE_ARRAY_SIZE.
             * This means that the RFFT value will occupy the first position
             * of a channles vector and the rest needs to be filled with zeros.
             */

            memset((void *)dram0_line_ptr, 0, MODEL_INPUT_LINE_SIZE);

            /*
             * A full line of RFFT RX buffer contains magnitudes of complex
             * Fourier transform, which for purely real input produces
             * Hermitian symmetry. Thus MODEL_INPUT_WIDTH is equal to
             * RFFT_RX_FRAME_WIDTH / 2 + 1 and the rest of RFFT RX line
             * can be ignored.
             *
             * https://en.wikipedia.org/wiki/Fourier_transform
             *
             * Xilinx FFT documentation recommends taking values from the
             * second (upper) half of the line due to lesser precision noise.
             *
             * https://docs.xilinx.com/r/en-US/pg109-xfft/Real-Valued-Input-Data
             */

            for (size_t j = 0; j < MODEL_INPUT_WIDTH; j++) {
                ((MODEL_DT *)dram0_line_ptr)[j * MODEL_VECTOR_LENGTH] = ((
                    MODEL_DT *)rfft_rx_line_ptr)[RFFT_RX_FRAME_WIDTH - (j + 1)];
            }
        }

        rfft_line = (rfft_line + 1) % RFFT_RX_FRAME_HEIGHT;

        /*
         * For debugging purposes we count the number of cycles
         * being spent waiting for the next acquisition packet.
         *
         * We report if this number drops below 100,000 cycles (1ms).
         */

        XTmrCtr_Reset(&tmr_ctr, 0);
        XTmrCtr_Start(&tmr_ctr, 0);

        while (XAxiDma_Busy(&acq_axi_dma, XAXIDMA_DEVICE_TO_DMA))
            ;

        XTmrCtr_Stop(&tmr_ctr, 0);
        u32 cycles = XTmrCtr_GetValue(&tmr_ctr, 0);

        if (cycles < 100000)
            xil_printf("CYCLES: %d\r\n", cycles);
    }

error:
    cleanup_platform();
    return 0;
}
