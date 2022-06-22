`timescale 1ps/1ps

module adcs747x_to_axism
    #(
    parameter DATA_WIDTH = 16,
    parameter PACKET_SIZE = 128,
    parameter SPI_SCK_DIV = 200
)
    
    (
    output wire SPI_SSN,
    output wire SPI_SCK,
    input wire SPI_MISO,
    input wire AXIS_ACLK,
    input wire AXIS_ARESETN,
    output wire M_AXIS_TVALID,
    output wire [15:0] M_AXIS_TDATA,
    output wire [1:0] M_AXIS_TSTRB,
    output wire M_AXIS_TLAST,
    input wire M_AXIS_TREADY
);
    localparam SPI_SCK_PERIOD_DIV = SPI_SCK_DIV / 2;

    reg [$clog2(SPI_SCK_PERIOD_DIV) - 1:0] spi_sck_counter;
    reg spi_sck;
    reg spi_sck_last;

    reg [$clog2(DATA_WIDTH) - 1:0] spi_ssn_counter;
    reg spi_ssn;
    reg spi_ssn_last;

    reg [DATA_WIDTH - 1:0] spi_sample;

    reg [DATA_WIDTH - 1:0] m_axis_tdata;

    reg m_axis_tvalid;
    reg m_axis_tlast;

    reg [$clog2(PACKET_SIZE) - 1:0] packet_counter;

    always@(posedge AXIS_ACLK) begin
        if(!AXIS_ARESETN) begin
            spi_ssn_counter <= 0;
            spi_ssn <= 0;
            spi_ssn_last <= 0;

            spi_sck_counter <= 0;
            spi_sck <= 0;
            spi_sck_last <= 0;

            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tdata <= {DATA_WIDTH{1'b0}};

            packet_counter <= 0;
        end else begin
            if (spi_sck_counter == SPI_SCK_PERIOD_DIV - 1) begin
                spi_sck <= !spi_sck;
                spi_sck_counter <= 0;
            end else begin
                spi_sck_counter <= spi_sck_counter + 1;
            end

            if (!spi_sck_last && spi_sck) begin
                spi_sample <= {spi_sample[DATA_WIDTH - 2:0], SPI_MISO};
            end

            if (spi_sck_last && !spi_sck) begin
                if (spi_ssn_counter == DATA_WIDTH - 1) begin
                    spi_ssn <= !spi_ssn;
                    spi_ssn_counter <= 0;
                end else begin
                    spi_ssn_counter <= spi_ssn_counter + 1;
                end
            end

            if (!spi_ssn_last && spi_ssn) begin
                m_axis_tvalid <= 1'b1;
                m_axis_tlast <= 1'b0;

                if (M_AXIS_TREADY) begin
                    if (packet_counter == PACKET_SIZE - 1) begin
                        m_axis_tlast <= 1'b1;
                        packet_counter <= 0;
                    end else begin
                        packet_counter <= packet_counter + 1;
                    end
                end

                m_axis_tdata <= spi_sample;
            end else begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast <= 1'b0;
            end

            spi_ssn_last <= spi_ssn;
            spi_sck_last <= spi_sck;
        end
    end

    assign SPI_SCK = spi_sck;
    assign SPI_SSN = spi_ssn;

    assign M_AXIS_TSTRB = 2'b1;
    assign M_AXIS_TVALID = m_axis_tvalid;
    assign M_AXIS_TLAST = m_axis_tlast;
    assign M_AXIS_TDATA = m_axis_tdata;

endmodule
