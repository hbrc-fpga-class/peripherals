/* Example of NOT instantiating a latch. */

module latch3
(
    input wire clk_16mhz,
    input wire button0,
    input wire button1,
    output reg led
);

always @ (posedge clk_16mhz)
begin
    if (button0) begin
        led <= button1;
    end
end

endmodule
