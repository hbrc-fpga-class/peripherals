/* Example of NOT instantiating a latch. */

module latch2
(
    input wire button0,
    input wire button1,
    output reg led
);

always @ (*)
begin
    if (button0) begin
        led <= button1;
    end else begin
        led <= 0;
    end
end

endmodule
