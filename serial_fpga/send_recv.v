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

    // user interface
    input wire [7:0] in_tx_data,
    input wire in_wr,
    output reg out_rx_valid,

    // TX uart interface
    output reg [7:0] out_tx_data,
    output reg out_wr_strobe,
    input wire in_tx_busy,

    // RX uart interface
    input wire [7:0] in_rx_data,
    input wire in_rx_valid,
    output reg out_rd_strobe
);

reg [7:0] in_tx_data_reg;
reg [2:0] send_recv_state;

// States
localparam IDLE         = 1;
localparam WRITE_CHAR   = 2;
localparam READ_CHAR    = 3;

always @ (posedge clk)
begin
    if (reset) begin
        out_wr_strobe <= 0;
        out_rd_strobe <= 0;
        out_rx_valid <= 0;
        in_tx_data_reg <= 0;
        out_tx_data <= 0;
    end else begin
        case (send_recv_state)
            IDLE : begin
                out_wr_strobe <= 0;
                out_rd_strobe <= 0;
                out_rx_valid <= 0;

                if (in_wr) begin
                    // Start the transaction
                    in_tx_data_reg <= in_tx_data;
                    send_recv_state <= WRITE_CHAR;
                end
            end
            WRITE_CHAR : begin
                // Send the char
                if (!in_tx_busy) begin
                    out_tx_data <= in_tx_data_reg;
                    out_wr_strobe <= 1;
                    send_recv_state <= READ_CHAR;
                end
            end
            READ_CHAR : begin
                // Wait for reception of char to proceed
                if (in_rx_valid) begin
                    // Received a byte
                    out_rd_strobe <= 1;
                    out_rx_valid <= 1;
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

