`timescale 1ns/1ns
`include "stoplight.v"



module tb_stoplight;

  reg clk, rst;
  wire red, yellow, green;
  wire [2:0] counter;

  // Instancia del DUT (Device Under Test)
  stoplight dut (
    .clk(clk),
    .rst(rst),
    .red(red),
    .yellow(yellow),
    .green(green),
    .counter(counter)
  );

  always begin
    clk = 1; #5;
    clk = 0; #5;
  end

  initial begin
    // Generación del archivo de ondas
    $dumpfile("stoplight.vcd");
    $dumpvars(0, tb_stoplight);

    rst = 1; #12;
    rst = 0; #100
    rst = 1; #18;
    rst = 0; #100
    #1000




    // Estímulos: probar las 4 combinaciones posibles


    // Fin de simulación
    $finish;
  end   

endmodule
