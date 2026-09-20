`timescale 1ns/1ns
`include "stoplight.v"
`timescale 1ns/1ns

// Comprueba la secuencia de luces, su duracion y el reset desde cada estado.
// Las tareas agrupan comprobaciones que se repiten durante la simulacion.
module tb_stoplight;
  reg clk, rst;
  wire red, yellow, green;
  wire [2:0] counter;
  // test_id identifica la prueba en GTKWave. Cada bit de reset_mask indica
  // si ya se probo el reset desde el estado del mismo numero.
  integer test_id, reset_mask;

  stoplight dut (
    .clk(clk), .rst(rst), .red(red), .yellow(yellow),
    .green(green), .counter(counter)
  );

  // Un cambio cada 5 ns produce un reloj de periodo 10 ns.
  initial clk = 0;
  always #5 clk = ~clk;

  // Una condicion falsa, desconocida (X) o flotante (Z) detiene la simulacion.
  // El mensaje permite localizar la prueba y el instante del fallo.
  task check;
    input condition;
    input [8*120-1:0] message;
    begin
      if (condition !== 1'b1)
        $fatal(1, "FAIL stoplight test=%0d t=%0t: %0s", test_id, $time, message);
    end
  endtask

  // Se observa en negedge, cuando las actualizaciones de posedge ya terminaron.
  task check_state;
    input [1:0] expected_state;
    input integer cycles;
    integer n;
    begin
      for (n = 0; n < cycles; n = n + 1) begin
        check(dut.state === expected_state, "estado o duracion incorrectos");
        check(counter === n[2:0], "contador incorrecto");
        check(green === (expected_state == 0), "green incorrecto");
        check(yellow === ((expected_state == 1) || (expected_state == 3)), "yellow incorrecto");
        check(red === (expected_state == 2), "red incorrecto");
        @(negedge clk);
      end
    end
  endtask

  // Se comprueban S0, S1, S2 y S3 con sus respectivas duraciones en ciclos.
  task full_sequence;
    begin
      check_state(2'd0, 5);
      check_state(2'd1, 2);
      check_state(2'd2, 4);
      check_state(2'd3, 2);
    end
  endtask

  // Espera el estado solicitado y verifica el retorno inmediato a verde.
  task reset_from_state;
    input [1:0] target;
    begin
      while (dut.state !== target) @(negedge clk);
      check(dut.state === target, "no se alcanzo el estado previo al reset");
      // Se activa entre flancos y se comprueba antes del siguiente flanco positivo.
      // Se desactiva en un flanco negativo para no coincidir con la actualizacion.
      #2 rst = 1;
      #1;
      check(dut.state === 2'd0 && counter === 3'd0, "reset asincrono incorrecto");
      check({green, yellow, red} === 3'b100, "salidas durante reset incorrectas");
      reset_mask = reset_mask | (1 << target);
      repeat (2) @(negedge clk);
      rst = 0;
      $display("OK stoplight reset desde S%0d, liberado t=%0t", target, $time);
    end
  endtask

  initial begin
    // Se guardan las señales del testbench y del modulo para revisarlas en GTKWave.
    $dumpfile("stoplight.vcd");
    $dumpvars(0, tb_stoplight);
    test_id = 0;
    reset_mask = 0;
    rst = 1;
    repeat (2) @(negedge clk);
    rst = 0;

    // Primero se verifica la operacion normal sin interrupciones.
    test_id = 1;
    full_sequence();
    full_sequence();
    $display("OK stoplight dos secuencias completas 5/2/4/2, t=%0t", $time);

    // Se cubren los cuatro estados de origen del reset.
    test_id = 2; reset_from_state(2'd0);
    test_id = 3; reset_from_state(2'd1);
    test_id = 4; reset_from_state(2'd2);
    test_id = 5; reset_from_state(2'd3);
    check(reset_mask == 15, "faltan estados en la cobertura de reset");

    // Se comprueba que el semaforo sigue funcionando despues de los resets.
    test_id = 6;
    full_sequence();
    $display("PASS stoplight: tiempos, luces y reset desde los cuatro estados");
    $finish;
  end

  initial begin
    // Evita una espera indefinida si el circuito no llega al estado esperado.
    #10000;
    $fatal(1, "Timeout stoplight");
  end
endmodule
