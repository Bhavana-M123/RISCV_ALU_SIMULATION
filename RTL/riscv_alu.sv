`timescale 1ns / 1ps

// RV32I ALU, registered output, 1-cycle latency.
// alu_op = {funct7[5], funct3}
module riscv_alu (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        in_valid,
  input  logic [3:0]  alu_op,
  input  logic [31:0] a,
  input  logic [31:0] b,
  output logic        out_valid,
  output logic [31:0] result,
  output logic        zero
);
  logic [31:0] res_c;
  logic [4:0]  shamt;
  assign shamt = b[4:0];

  always_comb begin
    case (alu_op)
      4'b0000: res_c = a + b;                              // ADD
      4'b1000: res_c = a - b;                              // SUB
      4'b0001: res_c = a << shamt;                         // SLL
      4'b0010: res_c = {31'b0, $signed(a) < $signed(b)};   // SLT
      4'b0011: res_c = {31'b0, a < b};                     // SLTU
      4'b0100: res_c = a ^ b;                              // XOR
      4'b0101: res_c = a >> shamt;                         // SRL
      4'b1101: res_c = $signed(a) >>> shamt;               // SRA
      4'b0110: res_c = a | b;                              // OR
      4'b0111: res_c = a & b;                              // AND
      default: res_c = '0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_valid <= 1'b0;
      result    <= '0;
      zero      <= 1'b0;
    end else begin
      out_valid <= in_valid;
      if (in_valid) begin
        result <= res_c;
        zero   <= (res_c == 32'h0);
      end
    end
  end
endmodule


