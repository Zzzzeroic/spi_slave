`default_nettype wire
module neg_edge_det ( input wire sig,            // Input signal for which positive edge has to be detected
                      input wire clk,            // Input signal for clock
                      output wire ne);           // Output signal that gives a pulse when a positive edge occurs
 
    reg[1:0]   sig_dly;                          // Internal signal to store the delayed version of signal
 
    // This always block ensures that sig_dly is exactly 1 clock behind sig
  always @ (posedge clk) begin
    sig_dly <= {sig_dly[0],sig};
  end
 
    // Combinational logic where sig is AND with delayed, inverted version of sig
    // Assign statement assigns the evaluated expression in the RHS to the internal net pe
  assign ne = (sig_dly==2'b10)?1:0;            
endmodule 

