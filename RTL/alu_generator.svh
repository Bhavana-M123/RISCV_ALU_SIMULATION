// ------------------------------------------------------------------ Generator
class alu_generator;
  mailbox #(alu_txn) gen2drv;
  int unsigned       num_txns = 1000;   // random txns (directed ones are extra)

  localparam int N_OPS = 10, N_CORNERS = 5;

  function new(mailbox #(alu_txn) m);
    gen2drv = m;
  endfunction

  function int unsigned total();
    return N_OPS * N_CORNERS * N_CORNERS + num_txns;
  endfunction

  function alu_op_e op_at(int i);
    case (i)
      0: return ALU_ADD;
      1: return ALU_SUB;
      2: return ALU_SLL;
      3: return ALU_SLT;
      4: return ALU_SLTU;
      5: return ALU_XOR;
      6: return ALU_SRL;
      7: return ALU_SRA;
      8: return ALU_OR;
      default: return ALU_AND;
    endcase
  endfunction

  function logic [31:0] corner_at(int i);
    case (i)
      0: return 32'h0000_0000;
      1: return 32'h0000_0001;
      2: return 32'hFFFF_FFFF;
      3: return 32'h8000_0000;
      default: return 32'h7FFF_FFFF;
    endcase
  endfunction

  // Directed phase: every op on every pair of corner operands
  task run_directed();
    alu_txn t;
    for (int i = 0; i < N_OPS; i++)
      for (int j = 0; j < N_CORNERS; j++)
        for (int k = 0; k < N_CORNERS; k++) begin
          t = new();
          t.op = op_at(i); t.a = corner_at(j); t.b = corner_at(k); t.gap = 0;
          gen2drv.put(t);
        end
  endtask

  // Constrained-random phase
  task run_random();
    alu_txn t;
    for (int n = 0; n < num_txns; n++) begin
      t = new();
      if (!t.randomize()) $fatal(1, "[GEN] randomization failed");
      gen2drv.put(t);
    end
  endtask

  task run();
    run_directed();
    run_random();
  endtask
endclass

