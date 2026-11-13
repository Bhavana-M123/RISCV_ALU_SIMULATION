// ---------------------------------------------------------------- Environment
class alu_env;
  alu_generator    gen;
  alu_driver       drv;
  alu_in_monitor   mon_i;
  alu_out_monitor  mon_o;
  alu_scoreboard   scb;
  alu_coverage     cov;

  mailbox #(alu_txn) gen2drv, mon_in2scb, mon_out2scb;
  virtual alu_if vif;

  function new(virtual alu_if vif);
    this.vif = vif;
    gen2drv     = new();
    mon_in2scb  = new();
    mon_out2scb = new();
    cov   = new();
    gen   = new(gen2drv);
    drv   = new(vif, gen2drv);
    mon_i = new(vif, mon_in2scb);
    mon_o = new(vif, mon_out2scb);
    scb   = new(mon_in2scb, mon_out2scb, cov);
  endfunction

  task run();
    int unsigned cycles;
    int unsigned timeout_cycles;
    timeout_cycles = 200 + 20 * gen.total();
    scb.expected_cnt = gen.total();

    fork
      gen.run();
      drv.run();
      mon_i.run();
      mon_o.run();
      scb.run();
    join_none

    cycles = 0;
    while (!scb.finished && cycles < timeout_cycles) begin
      @(posedge vif.clk);
      cycles++;
    end
    if (!scb.finished)
      $error("[ENV] TIMEOUT: checked %0d of %0d", scb.checked, scb.expected_cnt);
    repeat (5) @(posedge vif.clk);
    scb.report();
  endtask
endclass

