// Force error when implicit net has no type.
`default_nettype none

`timescale 1 ns / 1 ps


module pwm1_tb;

// Inputs (registers)
reg clk_16mhz;
reg button0;
reg button1;

// Output (wires)
wire [7:0] led;
wire pwm;
wire dir;
wire float_n;

// Instantiate DUT (device under test)
pwm1 pwm1_inst
(
    .clk_16mhz(clk_16mhz),
    .button0(button0),
    .button1(button1),
    .led(led),  // [7:0]

    // Motor pins
    .pwm(pwm),
    .dir(dir),
    .float_n(float_n)
);

// Main testbench code
initial begin
    $dumpfile("pwm1.vcd");
    $dumpvars(0, pwm1_tb);

    // init inputs
    clk_16mhz = 0;
    button0 = 1;
    button1 = 1;

    // Wait 10us
    #10000;
    button0 = 0;

    // Wait 10us
    #10000;
    button1 = 0;

    // Wait 30us
    #10000;

    // end simulation
    $display("done: ",$realtime);
    $finish;
end

// Generate a 16mhz clk
always begin
    #31.25 clk_16mhz = ~clk_16mhz;
end

// Count pwm pulse and period
reg pwm_pre = 0;
wire pwm_posedge = pwm && ~pwm_pre;
wire pwm_negedge = ~pwm && pwm_pre;

localparam WAIT_START_COUNT = 0;
localparam WAIT_PULSE_END   = 1;
localparam WAIT_PERIOD_END  = 2;
localparam DONE             = 3;
reg [1:0] state = WAIT_START_COUNT;
reg [7:0] period_count = 0;
always @ (posedge clk_16mhz)
begin
    pwm_pre <= pwm; // for edges
    case (state)
        WAIT_START_COUNT : begin
            if (pwm_posedge) begin
                period_count <= 1;
                state <= WAIT_PULSE_END;
            end
        end
        WAIT_PULSE_END : begin
            period_count <= period_count + 1;
            if (pwm_negedge) begin
                $display("pulse_count: ",period_count);
                state <= WAIT_PERIOD_END;
            end
        end
        WAIT_PERIOD_END : begin
            period_count <= period_count + 1;
            if (pwm_posedge) begin
                $display("period_count: ",period_count);
                state <= DONE;
            end 
        end
        DONE : begin
            // done, do nothing
        end
        default : begin
            state <= WAIT_START_COUNT;
        end
    endcase
end

endmodule

