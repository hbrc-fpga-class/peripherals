/*
*****************************
* MODULE : send_recv
*
* This module send 1 character to the uart
* a waits to receive a character before 
* asserting done.
*
* Status: In development
*
* Author : Brandon Blodget
* Create Date: 05/11/2019
*
*****************************
*/

// Force error when implicit net has no type.
`default_nettype none

module send_recv
(
    input wire clk,
    input wire reset,

    // control interface
    input wire [7:0] serial_tx_data,
    input wire serial_wr,
    input wire serial_rd,
    output reg serial_valid,
    output reg [7:0] serial_rx_data,

    // TX uart interface
    output reg [7:0] tx_data,
    output reg tx_wr_strobe,
    input wire tx_busy,

    // RX uart interface
    input wire [7:0] rx_data,
    input wire rx_valid,
    output reg rx_rd_strobe
);

reg [7:0] serial_tx_data_reg;
reg [2:0] send_recv_state;

// States
localparam IDLE         = 0;
localparam WRITE_CHAR   = 1;
localparam READ_CHAR    = 2;

always @ (posedge clk)
begin
    if (reset) begin
        tx_wr_strobe <= 0;
        rx_rd_strobe <= 0;
        serial_valid <= 0;
        serial_tx_data_reg <= 0;
        tx_data <= 0;
        serial_rx_data <= 0;
    end else begin
        case (send_recv_state)
            IDLE : begin
                tx_wr_strobe <= 0;
                rx_rd_strobe <= 0;
                serial_valid <= 0;

                if (serial_wr) begin
                    // Write then read
                    serial_tx_data_reg <= serial_tx_data;
                    send_recv_state <= WRITE_CHAR;
                end

                if (serial_rd) begin
                    // Read only
                    send_recv_state <= READ_CHAR;
                end
            end
            WRITE_CHAR : begin
                // Send the char
                if (!tx_busy) begin
                    tx_data <= serial_tx_data_reg;
                    tx_wr_strobe <= 1;
                    send_recv_state <= READ_CHAR;
                end
            end
            READ_CHAR : begin
                tx_wr_strobe <= 0;
                // Wait for reception of char to proceed
                if (rx_valid) begin
                    // Received a byte
                    rx_rd_strobe <= 1;
                    serial_valid <= 1;
                    serial_rx_data <= rx_data;
                    send_recv_state <= IDLE;
                end
            end
            default : begin
                send_recv_state <= IDLE;
            end
        endcase
    end
end

endmodule

