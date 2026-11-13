typedef enum logic [3:0] {
  ALU_ADD  = 4'b0000,
  ALU_SUB  = 4'b1000,
  ALU_SLL  = 4'b0001,
  ALU_SLT  = 4'b0010,
  ALU_SLTU = 4'b0011,
  ALU_XOR  = 4'b0100,
  ALU_SRL  = 4'b0101,
  ALU_SRA  = 4'b1101,
  ALU_OR   = 4'b0110,
  ALU_AND  = 4'b0111
} alu_op_e;

// ---------------------------------------------------------------- Transaction
class alu_txn;
  rand alu_op_e     op;
  rand logic [31:0] a, b;
  rand int unsigned gap;          // idle cycles before this txn is driven

  // observed
  logic [31:0] result;
  logic        zero;

  constraint c_gap { gap <= 8; }

  // Operand shaping is done in post_randomize (no dist constraints).
  function logic [31:0] pick_operand(logic [31:0] r);
    int s;
    s = $urandom_range(0, 99);
    if      (s <  8) return 32'h0000_0000;
    else if (s < 16) return 32'hFFFF_FFFF;
    else if (s < 24) return 32'h8000_0000;
    else if (s < 32) return 32'h7FFF_FFFF;
    else if (s < 37) return 32'h0000_0001;
    else             return r;
  endfunction

  function logic [4:0] pick_shamt(logic [4:0] r);
    int s;
    s = $urandom_range(0, 99);
    if      (s < 10) return 5'd0;
    else if (s < 20) return 5'd1;
    else if (s < 30) return 5'd31;
    else             return r;
  endfunction

  function void post_randomize();
    int s;
    a = pick_operand(a);
    b = pick_operand(b);
    if (op == ALU_SLL || op == ALU_SRL || op == ALU_SRA)
      b[4:0] = pick_shamt(b[4:0]);
    s = $urandom_range(0, 99);
    if (s < 70) gap = 0;
    else        gap = $urandom_range(1, 8);
  endfunction

  function string sprint();
    return $sformatf("op=%s a=0x%08h b=0x%08h -> res=0x%08h zero=%0b",
                     op.name(), a, b, result, zero);
  endfunction
endclass

