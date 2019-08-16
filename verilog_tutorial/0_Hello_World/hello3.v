module hello3;
always
begin
    #1      // delay one simulation step (unitless by default)
    $display("Hello World3: ",$time);
    if ($time == 100) begin
        $finish;
    end
end
endmodule

