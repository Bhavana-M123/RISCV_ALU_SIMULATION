// --------------------------------------------------------------------- Driver
// Drives with non-blocking assignments right after the clock edge, so the DUT
// (which samples at the edge) never races with the testbench.
class alu_driver;
  virtual alu_if     vif;
  mailbox #(alu_txn) gen2drv;

  function new(virtual alu_if vif, mailbox #(alu_txn) m);
    this.vif = vif; gen2drv = m;
  endfunction

  task run();
    alu_txn t;
    vif.in_valid <= 1'b0;
    vif.alu_op   <= '0;
    vif.a        <= '0;
    vif.b        <= '0;
    wait (vif.rst_n === 1'b1);
    @(posedge vif.clk);
    forever begin
      gen2drv.get(t);
      for (int g = 0; g < t.gap; g++) @(posedge vif.clk);
      vif.in_valid <= 1'b1;
      vif.alu_op   <= t.op;
      vif.a        <= t.a;
      vif.b        <= t.b;
      @(posedge vif.clk);
      vif.in_valid <= 1'b0;   // overridden by next txn if gap==0
    end
  endtask
endclass

