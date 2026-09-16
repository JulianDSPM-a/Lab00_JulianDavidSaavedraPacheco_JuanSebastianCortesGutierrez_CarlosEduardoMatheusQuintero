`timescale 1ns/1ns
`include "control_bytetx.v"

module tb_bytetx;

  parameter CLKS_PER_BIT = 4;

  reg        clk, rst;
  reg  [7:0] data_in;
  reg        start;
  wire       done, busy, tx;

  integer    errors;
  reg  [7:0] recibido;
  integer    k;

  control_bytetx dut (
    .clk(clk), .rst(rst),
    .data_in(data_in), .start(start),
    .done(done), .busy(busy), .tx(tx)
  );

  always begin
    clk = 1; #5;
    clk = 0; #5;
  end

  task enviar(input [7:0] dato);
    begin
      @(negedge clk);
      data_in = dato;
      start   = 1'b1;
      @(negedge clk);
      start   = 1'b0;

      wait (busy);
      @(negedge clk);

      for (k = 0; k < 8; k = k + 1) begin
        repeat (CLKS_PER_BIT/2) @(negedge clk);
        recibido[k] = tx;
        repeat (CLKS_PER_BIT - CLKS_PER_BIT/2) @(negedge clk);
      end

      wait (done);

      if (recibido !== dato) begin
        $display("ERROR t=%0t: envie %b, recibi %b", $time, dato, recibido);
        errors = errors + 1;
      end
      else
        $display("OK t=%0t: %b transmitido correctamente", $time, dato);
    end
 endtask

  initial begin
    $dumpfile("bytetx.vcd");
    $dumpvars(0, tb_bytetx);

    errors  = 0;
    start   = 1'b0;
    data_in = 8'h00;

    rst = 1; #12;
    rst = 0; #20;

    enviar(8'b1010_0101);
    #30;
    enviar(8'b1111_0000);
    #30;
    enviar(8'b0000_0001);

    #50;
    $display("--- terminado con %0d errores ---", errors);
    $finish;
  end

endmodule