// ------------------------------------------------------------------- Monitors
// Input monitor: captures stimulus actually presented to the DUT.
class alu_in_monitor;
  virtual alu_if     vif;
  mailbox #(alu_txn) mbx;
  function new(virtual alu_if vif, mailbox #(alu_txn) m);
    this.vif = vif; mbx = m;
  endfunction
  task run();
    alu_txn t;
    wait (vif.rst_n === 1'b1);
    forever begin
      @(posedge vif.clk);
      if (vif.in_valid === 1'b1) begin
        t = new();
        t.op = alu_op_e'(vif.alu_op);
        t.a  = vif.a;
        t.b  = vif.b;
        mbx.put(t);
      end
    end
  endtask
endclass

// Output monitor: captures DUT results.
class alu_out_monitor;
  virtual alu_if     vif;
  mailbox #(alu_txn) mbx;
  function new(virtual alu_if vif, mailbox #(alu_txn) m);
    this.vif = vif; mbx = m;
  endfunction
  task run();
    alu_txn t;
    wait (vif.rst_n === 1'b1);
    forever begin
      @(posedge vif.clk);
      if (vif.out_valid === 1'b1) begin
        t = new();
        t.result = vif.result;
        t.zero   = vif.zero;
        mbx.put(t);
      end
    end
  endtask
endclass

