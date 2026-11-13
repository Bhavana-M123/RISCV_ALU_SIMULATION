// ----------------------------------------------------------------------- Test
class alu_test;
  alu_env env;
  function new(virtual alu_if vif);
    env = new(vif);
  endfunction
  task run();
    int unsigned n;
    if ($value$plusargs("NUM_TXNS=%d", n)) env.gen.num_txns = n;
    env.run();
  endtask
endclass

