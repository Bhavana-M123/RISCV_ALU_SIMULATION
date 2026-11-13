// ------------------------------------------------------------------- Coverage
// Manual (covergroup-free) functional coverage so it also works in xsim.
// Bins: op hit, op x a-class x b-class, op x zero-flag, shift-amount class.
class alu_coverage;
  localparam int N_OPS = 10;
  localparam int N_CLS = 5;   // 0:zero 1:all-ones 2:min_neg 3:max_pos 4:other

  bit op_hit [N_OPS];
  bit x_hit  [N_OPS*N_CLS*N_CLS];
  bit z_hit  [N_OPS*2];
  bit sh_hit [12];            // SLL/SRL/SRA x {0,1,31,mid}

  function int op_idx(alu_op_e op);
    case (op)
      ALU_ADD : return 0;
      ALU_SUB : return 1;
      ALU_SLL : return 2;
      ALU_SLT : return 3;
      ALU_SLTU: return 4;
      ALU_XOR : return 5;
      ALU_SRL : return 6;
      ALU_SRA : return 7;
      ALU_OR  : return 8;
      ALU_AND : return 9;
      default : return 0;
    endcase
  endfunction

  function int val_cls(logic [31:0] v);
    if (v == 32'h0000_0000) return 0;
    if (v == 32'hFFFF_FFFF) return 1;
    if (v == 32'h8000_0000) return 2;
    if (v == 32'h7FFF_FFFF) return 3;
    return 4;
  endfunction

  function int sh_cls(logic [4:0] s);
    if (s == 5'd0)  return 0;
    if (s == 5'd1)  return 1;
    if (s == 5'd31) return 2;
    return 3;
  endfunction

  function void sample(alu_txn tr);
    int o, ac, bc, zi, si;
    o  = op_idx(tr.op);
    ac = val_cls(tr.a);
    bc = val_cls(tr.b);
    zi = tr.zero ? 1 : 0;
    op_hit[o] = 1'b1;
    x_hit[(o*N_CLS + ac)*N_CLS + bc] = 1'b1;
    z_hit[o*2 + zi] = 1'b1;
    if (tr.op == ALU_SLL || tr.op == ALU_SRL || tr.op == ALU_SRA) begin
      si = (tr.op == ALU_SLL) ? 0 : (tr.op == ALU_SRL) ? 1 : 2;
      sh_hit[si*4 + sh_cls(tr.b[4:0])] = 1'b1;
    end
  endfunction

  function real get_cov();
    int hit, total;
    hit = 0; total = 0;
    for (int i = 0; i < N_OPS; i++)         begin total++; if (op_hit[i]) hit++; end
    for (int i = 0; i < N_OPS*N_CLS*N_CLS; i++) begin total++; if (x_hit[i])  hit++; end
    for (int i = 0; i < N_OPS*2; i++)       begin total++; if (z_hit[i])  hit++; end
    for (int i = 0; i < 12; i++)            begin total++; if (sh_hit[i]) hit++; end
    return 100.0 * hit / total;
  endfunction
endclass

