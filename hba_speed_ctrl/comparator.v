// Force error when implicit net has no type.
`default_nettype none

module comparator
(
    input wire clk,
    input wire reset,
    input wire en,
    input wire [7:0] in1,
    input wire [7:0] in2,

    output reg less_than,       // in1 < in2
    output reg equal,           // in1 = in2
    output reg greater_than     // in1 > in2
);


always @ (posedge clk)
begin
    if (reset) begin
        less_than <= 0;
        equal <= 0;
        greater_than <= 0;
    end else begin
        if (en) begin
            if (in1 == in2) begin
                equal <= 1;
            end else if (in1 < in2) begin
                less_than <= 1;
            end else begin
                greater_than <= 1;
            end
        end
    end
end

endmodule

