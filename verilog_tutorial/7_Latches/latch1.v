/* Example of instantiating a latch. */

module latch1
(
    input wire button0,
    input wire button1,
    output reg led
);

always @ (*)
begin
    if (button0) begin
        led <= button1;
    end
end

endmodule
