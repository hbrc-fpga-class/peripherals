// Force error when implicit net has no type.
`default_nettype none

module up_down_counter
(
    input wire clk,
    input wire reset,
    input wire en,
    input wire load,

    input wire [7:0] init_value,
    input wire up,
    input wire down,

    output reg [7:0] out_value
);

always @ (posedge clk)
begin
    if (reset) begin
        out_value <= 0;
    end else begin
        if (load) begin
            out_value <= init_value;
        end else begin
            if (en) begin
                if (up==1 && out_value<100) begin
                    out_value <= out_value + 1;
                end else if (down==1 && out_value>0) begin
                    out_value <= out_value - 1;
                end
            end
        end
    end
end

endmodule

