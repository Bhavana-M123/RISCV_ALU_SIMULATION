// ----------------------------------------------------------------- Scoreboard
class alu_scoreboard;
  mailbox #(alu_txn) in_mbx, out_mbx;
  alu_coverage       cov;
  int unsigned       expected_cnt;
  int unsigned       checked, errors;
  bit                finished;

  function new(mailbox #(alu_txn) i, mailbox #(alu_txn) o, alu_coverage c);
    in_mbx = i; out_mbx = o; cov = c;
  endfunction

  // Golden reference model
  function logic [31:0] ref_model(alu_op_e op, logic [31:0] a, logic [31:0] b);
    logic signed [31:0] sa;
    sa = a;
    case (op)
      ALU_ADD : return a + b;
      ALU_SUB : return a - b;
      ALU_SLL : return a << b[4:0];
      ALU_SLT : return {31'b0, ($signed(a) < $signed(b))};
      ALU_SLTU: return {31'b0, (a < b)};
      ALU_XOR : return a ^ b;
      ALU_SRL : return a >> b[4:0];
      ALU_SRA : return sa >>> b[4:0];
      ALU_OR  : return a | b;
      ALU_AND : return a & b;
      default : return 32'h0;
    endcase
  endfunction

  task run();
    alu_txn exp_t, act_t;
    logic [31:0] exp_res;
    forever begin
      in_mbx.get(exp_t);
      out_mbx.get(act_t);
      exp_res = ref_model(exp_t.op, exp_t.a, exp_t.b);
      exp_t.result = act_t.result;
      exp_t.zero   = act_t.zero;
      checked++;
      if (act_t.result !== exp_res || act_t.zero !== (exp_res == 32'h0)) begin
        errors++;
        $error("[SCB] MISMATCH #%0d: %s | expected res=0x%08h zero=%0b",
               checked, exp_t.sprint(), exp_res, (exp_res == 32'h0));
      end
      cov.sample(exp_t);
      if (checked == expected_cnt) finished = 1'b1;
    end
  endtask

  function void report();
    $display("--------------------------------------------------");
    $display(" SCOREBOARD: checked=%0d/%0d errors=%0d", checked, expected_cnt, errors);
    $display(" FUNCTIONAL COVERAGE: %0.2f%%", cov.get_cov());
    $display(" RESULT: %s", (errors == 0 && checked == expected_cnt) ? "PASS" : "FAIL");
    $display("--------------------------------------------------");
  endfunction
endclass

