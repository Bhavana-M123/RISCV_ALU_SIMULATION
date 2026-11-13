`timescale 1ns/1ps
module tb_top;
  import alu_pkg::*;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  alu_if intf (clk, rst_n);

  riscv_alu dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid (intf.in_valid), .alu_op(intf.alu_op),
    .a(intf.a), .b(intf.b),
    .out_valid(intf.out_valid), .result(intf.result), .zero(intf.zero)
  );

  initial begin
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  alu_test test;
  initial begin
    test = new(intf);
    test.run();
    $finish;
  end
endmodule
