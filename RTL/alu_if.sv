
`timescale 1ns / 1ps
// Plain interface (no clocking blocks: keeps xsim happy).
interface alu_if (input logic clk, input logic rst_n);
  logic        in_valid;
  logic [3:0]  alu_op;
  logic [31:0] a, b;
  logic        out_valid;
  logic [31:0] result;
  logic        zero;
endinterface
