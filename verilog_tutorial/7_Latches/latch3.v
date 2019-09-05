/* Example of NOT instantiating a latch. */

module latch3
(
    input wire clk_16mhz,
    input wire button0,
    output reg [7:0] led
);

wire en = button0;
reg [1:0] count = 0;

assign led = {6'h0,count[1:0]};

always @ (posedge clk_16mhz)
begin
    if (en) begin
        count <= count + 1;
    end
end

endmodule
