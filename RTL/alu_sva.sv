
`timescale 1ns / 1ps
// =============================================================================
// alu_sva.sv  -  SystemVerilog Assertions for riscv_alu
//
// Bound onto the DUT (see the bind statement at the bottom), so the existing
// testbench and RTL need NO changes. All assertions are clocked on posedge clk
// and sampled in the Preponed region, so they are race-free with the class
// driver (which drives with non-blocking assignments after the clock edge).
//
// DUT timing: registered output, 1-cycle latency
//   cycle N   : in_valid, alu_op, a, b presented
//   cycle N+1 : out_valid, result, zero visible
// =============================================================================
module alu_sva (
  input logic        clk,
  input logic        rst_n,
  input logic        in_valid,
  input logic [3:0]  alu_op,
  input logic [31:0] a,
  input logic [31:0] b,
  input logic        out_valid,
  input logic [31:0] result,
  input logic        zero
);

  // ---------------------------------------------------------------- opcodes
  localparam logic [3:0] OP_ADD  = 4'b0000;
  localparam logic [3:0] OP_SUB  = 4'b1000;
  localparam logic [3:0] OP_SLL  = 4'b0001;
  localparam logic [3:0] OP_SLT  = 4'b0010;
  localparam logic [3:0] OP_SLTU = 4'b0011;
  localparam logic [3:0] OP_XOR  = 4'b0100;
  localparam logic [3:0] OP_SRL  = 4'b0101;
  localparam logic [3:0] OP_SRA  = 4'b1101;
  localparam logic [3:0] OP_OR   = 4'b0110;
  localparam logic [3:0] OP_AND  = 4'b0111;

  // Independent reference function (kept separate from the RTL expressions)
  function automatic logic [31:0] ref_alu (input logic [3:0]  op,
                                           input logic [31:0] x,
                                           input logic [31:0] y);
    logic signed [31:0] sx, sy;
    sx = x; sy = y;
    case (op)
      OP_ADD : ref_alu = x + y;
      OP_SUB : ref_alu = x - y;
      OP_SLL : ref_alu = x << y[4:0];
      OP_SLT : ref_alu = {31'b0, (sx < sy)};
      OP_SLTU: ref_alu = {31'b0, (x < y)};
      OP_XOR : ref_alu = x ^ y;
      OP_SRL : ref_alu = x >> y[4:0];
      OP_SRA : ref_alu = sx >>> y[4:0];
      OP_OR  : ref_alu = x | y;
      OP_AND : ref_alu = x & y;
      default: ref_alu = 32'h0;
    endcase
  endfunction

  // Failure bookkeeping (printed by the final block)
  int unsigned fail_cnt = 0;

  // ====================================================================
  // 1. RESET
  //    Outputs are 0 on any cycle where reset has been low for >= 2 clocks.
  //    (First clock edge is skipped: $past is X there.)
  // ====================================================================
  a_reset_outputs: assert property (
    @(posedge clk)
    (!rst_n && !$past(rst_n)) |-> (out_valid === 1'b0 && result === 32'h0 && zero === 1'b0)
  ) else begin fail_cnt++; $error("[SVA] a_reset_outputs: outputs not cleared during reset"); end

  // ====================================================================
  // 2. INPUT PROTOCOL / X-CHECKS (after reset release)
  // ====================================================================
  a_in_valid_known: assert property (
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(in_valid)
  ) else begin fail_cnt++; $error("[SVA] a_in_valid_known: in_valid is X/Z"); end

  a_in_payload_known: assert property (
    @(posedge clk) disable iff (!rst_n)
    in_valid |-> !$isunknown({alu_op, a, b})
  ) else begin fail_cnt++; $error("[SVA] a_in_payload_known: alu_op/a/b X/Z while in_valid"); end

  a_legal_opcode: assert property (
    @(posedge clk) disable iff (!rst_n)
    in_valid |-> (alu_op inside {OP_ADD, OP_SUB, OP_SLL, OP_SLT, OP_SLTU,
                                 OP_XOR, OP_SRL, OP_SRA, OP_OR,  OP_AND})
  ) else begin fail_cnt++; $error("[SVA] a_legal_opcode: illegal alu_op=%b driven with in_valid", alu_op); end

  // ====================================================================
  // 3. OUTPUT TIMING / HANDSHAKE
  // ====================================================================
  // out_valid is exactly in_valid delayed by one clock (no drops, no spurious)
  a_latency_valid: assert property (
    @(posedge clk) disable iff (!rst_n)
    in_valid |=> out_valid
  ) else begin fail_cnt++; $error("[SVA] a_latency_valid: in_valid not followed by out_valid next cycle"); end

  a_no_spurious_valid: assert property (
    @(posedge clk) disable iff (!rst_n)
    !in_valid |=> !out_valid
  ) else begin fail_cnt++; $error("[SVA] a_no_spurious_valid: out_valid asserted without in_valid"); end

  a_out_valid_known: assert property (
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(out_valid)
  ) else begin fail_cnt++; $error("[SVA] a_out_valid_known: out_valid is X/Z"); end

  a_out_payload_known: assert property (
    @(posedge clk) disable iff (!rst_n)
    out_valid |-> !$isunknown({result, zero})
  ) else begin fail_cnt++; $error("[SVA] a_out_payload_known: result/zero X/Z while out_valid"); end

  // Result/zero hold their value on idle cycles (DUT only updates on in_valid)
  a_hold_when_idle: assert property (
    @(posedge clk) disable iff (!rst_n)
    !in_valid |=> ($stable(result) && $stable(zero))
  ) else begin fail_cnt++; $error("[SVA] a_hold_when_idle: result/zero changed without in_valid"); end

  // ====================================================================
  // 4. ZERO FLAG
  // ====================================================================
  a_zero_flag: assert property (
    @(posedge clk) disable iff (!rst_n)
    out_valid |-> (zero == (result == 32'h0))
  ) else begin fail_cnt++; $error("[SVA] a_zero_flag: zero=%0b but result=0x%08h", zero, result); end

  // ====================================================================
  // 5. FUNCTIONAL CORRECTNESS, one assertion per operation
  //    Inputs from cycle N are checked against the result seen at N+1.
  // ====================================================================
    // History registers for failure messages ($past is not allowed in an action block in xsim)
  logic [3:0]  d1_op, d2_op;
  logic [31:0] d1_a, d1_b, d2_a, d2_b, r_d1;
  always_ff @(posedge clk) begin
    d1_op <= alu_op; d1_a <= a; d1_b <= b;
    d2_op <= d1_op;  d2_a <= d1_a; d2_b <= d1_b;
    r_d1  <= result;
  end

  `define SVA_ERR(NAME) begin fail_cnt++; \
    $error("[SVA] %s: op=%b a=0x%08h b=0x%08h exp=0x%08h got=0x%08h", NAME, \
           d2_op, d2_a, d2_b, ref_alu(d2_op, d2_a, d2_b), r_d1); end

  a_op_add: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_ADD)  |=> (result == ref_alu(OP_ADD,  $past(a), $past(b))))
    else `SVA_ERR("a_op_add")
  a_op_sub: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_SUB)  |=> (result == ref_alu(OP_SUB,  $past(a), $past(b))))
    else `SVA_ERR("a_op_sub")
  a_op_sll: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_SLL)  |=> (result == ref_alu(OP_SLL,  $past(a), $past(b))))
    else `SVA_ERR("a_op_sll")
  a_op_slt: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_SLT)  |=> (result == ref_alu(OP_SLT,  $past(a), $past(b))))
    else `SVA_ERR("a_op_slt")
  a_op_sltu: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_SLTU) |=> (result == ref_alu(OP_SLTU, $past(a), $past(b))))
    else `SVA_ERR("a_op_sltu")
  a_op_xor: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_XOR)  |=> (result == ref_alu(OP_XOR,  $past(a), $past(b))))
    else `SVA_ERR("a_op_xor")
  a_op_srl: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_SRL)  |=> (result == ref_alu(OP_SRL,  $past(a), $past(b))))
    else `SVA_ERR("a_op_srl")
  a_op_sra: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_SRA)  |=> (result == ref_alu(OP_SRA,  $past(a), $past(b))))
    else `SVA_ERR("a_op_sra")
  a_op_or: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_OR)   |=> (result == ref_alu(OP_OR,   $past(a), $past(b))))
    else `SVA_ERR("a_op_or")
  a_op_and: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_AND)  |=> (result == ref_alu(OP_AND,  $past(a), $past(b))))
    else `SVA_ERR("a_op_and")

  // Illegal opcode must produce 0 (RTL default branch)
  a_illegal_op_zero: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && !(alu_op inside {OP_ADD,OP_SUB,OP_SLL,OP_SLT,OP_SLTU,
                                  OP_XOR,OP_SRL,OP_SRA,OP_OR,OP_AND})) |=> (result == 32'h0))
    else begin fail_cnt++; $error("[SVA] a_illegal_op_zero: non-zero result for illegal opcode"); end

  // ====================================================================
  // 6. ALGEBRAIC SANITY (extra independent checks, different formulation)
  // ====================================================================
  // x - x == 0  and  x ^ x == 0
  a_sub_self_zero: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_SUB && a == b) |=> (result == 32'h0 && zero))
    else begin fail_cnt++; $error("[SVA] a_sub_self_zero failed"); end
  a_xor_self_zero: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && alu_op == OP_XOR && a == b) |=> (result == 32'h0 && zero))
    else begin fail_cnt++; $error("[SVA] a_xor_self_zero failed"); end
  // SLT/SLTU produce only 0 or 1
  a_slt_one_bit: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && (alu_op == OP_SLT || alu_op == OP_SLTU)) |=> (result[31:1] == 31'h0))
    else begin fail_cnt++; $error("[SVA] a_slt_one_bit: upper bits set"); end
  // Shift by 0 is identity
  a_shift_by_zero: assert property (@(posedge clk) disable iff (!rst_n)
    (in_valid && (alu_op == OP_SLL || alu_op == OP_SRL || alu_op == OP_SRA) && b[4:0] == 5'd0)
    |=> (result == $past(a)))
    else begin fail_cnt++; $error("[SVA] a_shift_by_zero: shift by 0 altered value"); end

  // ====================================================================
  // 7. ASSERTION COVERAGE (cover property)
  // ====================================================================
  c_op_add : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_ADD);
  c_op_sub : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_SUB);
  c_op_sll : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_SLL);
  c_op_slt : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_SLT);
  c_op_sltu: cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_SLTU);
  c_op_xor : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_XOR);
  c_op_srl : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_SRL);
  c_op_sra : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_SRA);
  c_op_or  : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_OR);
  c_op_and : cover property (@(posedge clk) disable iff (!rst_n) in_valid && alu_op == OP_AND);

  c_back_to_back : cover property (@(posedge clk) disable iff (!rst_n) in_valid ##1 in_valid ##1 in_valid);
  c_idle_gap     : cover property (@(posedge clk) disable iff (!rst_n) in_valid ##1 !in_valid[*2:8] ##1 in_valid);
  c_zero_result  : cover property (@(posedge clk) disable iff (!rst_n) out_valid && zero);
  c_nonzero_res  : cover property (@(posedge clk) disable iff (!rst_n) out_valid && !zero);
  c_sra_negative : cover property (@(posedge clk) disable iff (!rst_n)
                                   in_valid && alu_op == OP_SRA && a[31] && b[4:0] != 0);
  c_add_overflow : cover property (@(posedge clk) disable iff (!rst_n)
                                   in_valid && alu_op == OP_ADD && a == 32'h7FFF_FFFF && b == 32'h1);
  c_slt_true     : cover property (@(posedge clk) disable iff (!rst_n)
                                   in_valid && alu_op == OP_SLT ##1 result == 32'h1);
  c_slt_false    : cover property (@(posedge clk) disable iff (!rst_n)
                                   in_valid && alu_op == OP_SLT ##1 result == 32'h0);

  // ---------------------------------------------------------------- summary
  final begin
    $display("--------------------------------------------------");
    $display(" SVA SUMMARY (%m): assertion failures = %0d  -> %s",
             fail_cnt, (fail_cnt == 0) ? "PASS" : "FAIL");
    $display("--------------------------------------------------");
  end

endmodule

// Attach the checker to every instance of riscv_alu; ports are matched by name.
bind riscv_alu alu_sva u_alu_sva (.*);

