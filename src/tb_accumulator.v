`timescale 1ns/1ps

// Verifica resultados parciales y finales, los cuatro modos y la cancelacion.
// Los estimulos y las lecturas se realizan en flancos negativos, separados
// del flanco positivo en el que el circuito actualiza sus registros.
module tb_accumulator;
  reg clk, reset, start, cancel;
  reg [1:0] num_veces;
  reg [3:0] num_suma;
  wire [5:0] acc;
  wire done;
  // Permite relacionar cada intervalo de GTKWave con una prueba concreta.
  integer test_id;
  integer mode_index, sum_index;

  accumulator uut (
    .clk(clk), .reset(reset), .start(start), .cancel(cancel),
    .num_veces(num_veces), .num_suma(num_suma), .acc(acc), .done(done)
  );

  // Periodo de reloj de 10 ns.
  initial clk = 0;
  always #5 clk = ~clk;

  // Solo se acepta un 1 conocido; una condicion falsa o indeterminada es un error.
  task check;
    input condition;
    input [8*120-1:0] message;
    begin
      if (condition !== 1'b1)
        $fatal(1, "FAIL accumulator test=%0d t=%0t: %0s", test_id, $time, message);
    end
  endtask

  // Aplica start durante un ciclo y espera a que LOAD limpie los registros.
  // Al terminar esta tarea, el circuito esta en ADD y aun no ha realizado sumas.
  task begin_operation;
    input integer id;
    input [1:0] mode;
    input [3:0] value;
    begin
      @(negedge clk);
      check(uut.state === 2'd0 && done === 1'b0, "se esperaba IDLE");
      test_id = id;
      num_veces = mode;
      num_suma = value;
      start = 1;
      @(negedge clk);
      check(uut.state === 2'd1, "start no produjo LOAD");
      start = 0;
      @(negedge clk);
      check(uut.state === 2'd2 && acc === 6'd0 && uut.counter === 3'd0,
            "LOAD no limpio el datapath");
    end
  endtask

  // Comprueba una suma. last_sum indica si debe coincidir con la entrada a DONE.
  task sum_cycle;
    input [5:0] expected_acc;
    input [4:0] expected_count;
    input last_sum;
    begin
      @(negedge clk);
      check(acc === expected_acc, "suma parcial incorrecta");
      check(uut.counter === expected_count, "numero de sumas incorrecto");
      check(done === last_sum, "done anticipado o ausente");
      if (last_sum) check(uut.state === 2'd3, "se esperaba DONE");
      else check(uut.state === 2'd2, "se esperaba ADD");
    end
  endtask

  // Verifica el resultado, que done dure un ciclo y que acc se conserve en reposo.
  task finish_operation;
    input [5:0] expected_acc;
    begin
      check(done === 1'b1 && acc === expected_acc, "resultado final incorrecto");
      $display("OK accumulator test=%0d acc=%0d, t=%0t", test_id, acc, $time);
      @(negedge clk);
      check(done === 1'b0 && uut.state === 2'd0, "done no duro un ciclo");
      check(acc === expected_acc, "resultado no se conserva en IDLE");
      repeat (2) @(negedge clk);
    end
  endtask

  // Se solicita cancelacion desde ADD. Todavia ocurre la suma de ese flanco;
  // last_acc es ese valor intermedio, antes de que LOAD borre los registros.
  task cancel_operation;
    input [5:0] last_acc;
    begin
      cancel = 1;
      @(negedge clk);
      check(uut.state === 2'd1 && done === 1'b0, "cancel debe tener prioridad");
      check(acc === last_acc, "suma al entrar en LOAD incorrecta");
      cancel = 0;
      @(negedge clk);
      check(uut.state === 2'd2 && acc === 6'd0 && uut.counter === 3'd0,
            "cancel no reinicio el datapath");
    end
  endtask

  initial begin
    // Incluye señales internas, como state y counter, para revisar la FSM.
    $dumpfile("accumulator.vcd");
    $dumpvars(0, tb_accumulator);
    test_id = 0;
    reset = 1; start = 0; cancel = 0;
    num_veces = 0; num_suma = 0;
    repeat (2) @(negedge clk);
    check(uut.state === 2'd0 && acc === 6'd0 && uut.counter === 3'd0 && done === 1'b0,
          "reset incorrecto");
    reset = 0;

    // Modo 01: tres sumas de 5, con resultado 15.
    begin_operation(1, 2'b01, 4'd5);
    sum_cycle(5, 1, 0); sum_cycle(10, 2, 0); sum_cycle(15, 3, 1);
    finish_operation(15);

    // Modo 10: cuatro sumas de 5, con resultado 20.
    begin_operation(2, 2'b10, 4'd5);
    sum_cycle(5, 1, 0); sum_cycle(10, 2, 0);
    sum_cycle(15, 3, 0); sum_cycle(20, 4, 1);
    finish_operation(20);

    // Modo 11: umbral de 20 con cancelacion. Con sumando 4 requiere cinco sumas.
    begin_operation(3, 2'b11, 4'd4);
    sum_cycle(4, 1, 0); sum_cycle(8, 2, 0);
    cancel_operation(12);
    sum_cycle(4, 1, 0); sum_cycle(8, 2, 0); sum_cycle(12, 3, 0);
    sum_cycle(16, 4, 0); sum_cycle(20, 5, 1);
    finish_operation(20);

    // Modo 00: 18 todavia es menor que 20; la ultima suma lleva el resultado a 24.
    begin_operation(4, 2'b00, 4'd6);
    sum_cycle(6, 1, 0); sum_cycle(12, 2, 0);
    sum_cycle(18, 3, 0); sum_cycle(24, 4, 1);
    finish_operation(24);

    // Igualdad exacta al umbral: debe terminar en 20, no en 25.
    begin_operation(5, 2'b00, 4'd5);
    sum_cycle(5, 1, 0); sum_cycle(10, 2, 0);
    sum_cycle(15, 3, 0); sum_cycle(20, 4, 1);
    finish_operation(20);

    // cancel y condicion de fin coinciden: debe ir a LOAD, no a DONE.
    begin_operation(6, 2'b01, 4'd5);
    sum_cycle(5, 1, 0); sum_cycle(10, 2, 0);
    cancel_operation(15);
    sum_cycle(5, 1, 0); sum_cycle(10, 2, 0); sum_cycle(15, 3, 1);
    finish_operation(15);

    // El modo 11 ya no significa cinco sumas: con 6 termina en cuatro, como 00.
    begin_operation(7, 2'b11, 4'd6);
    sum_cycle(6, 1, 0); sum_cycle(12, 2, 0);
    sum_cycle(18, 3, 0); sum_cycle(24, 4, 1);
    finish_operation(24);

    // Los modos de cantidad fija admiten el mayor sumando sin desbordar acc.
    begin_operation(8, 2'b01, 4'd15);
    sum_cycle(15, 1, 0); sum_cycle(30, 2, 0); sum_cycle(45, 3, 1);
    finish_operation(45);
    begin_operation(9, 2'b10, 4'd15);
    sum_cycle(15, 1, 0); sum_cycle(30, 2, 0);
    sum_cycle(45, 3, 0); sum_cycle(60, 4, 1);
    finish_operation(60);

    // Pruebas 10 a 13: todos los modos esperan en LOAD con sumando cero.
    // Al cambiarlo a 5, la operacion comienza sin otro pulso start.
    for (mode_index = 0; mode_index < 4; mode_index = mode_index + 1) begin
      @(negedge clk);
      test_id = 10 + mode_index;
      num_veces = mode_index; num_suma = 0; start = 1;
      @(negedge clk);
      check(uut.state === 2'd1, "se esperaba LOAD con sumando cero");
      start = 0;
      repeat (4) begin
        @(negedge clk);
        check(uut.state === 2'd1 && acc === 6'd0 && uut.counter === 5'd0 && done === 1'b0,
              "LOAD debe esperar con registros limpios y done desactivado");
      end
      num_suma = 5;
      @(negedge clk);
      check(uut.state === 2'd2 && acc === 6'd0, "no salio de LOAD al recibir sumando");
      sum_cycle(5, 1, 0); sum_cycle(10, 2, 0);
      if (mode_index == 1) begin
        sum_cycle(15, 3, 1); finish_operation(15);
      end
      else begin
        sum_cycle(15, 3, 0); sum_cycle(20, 4, 1); finish_operation(20);
      end
    end

    // Un cero durante ADD devuelve la operacion a LOAD; despues se reinicia.
    begin_operation(14, 2'b00, 4'd6);
    sum_cycle(6, 1, 0);
    num_suma = 0;
    @(negedge clk);
    check(uut.state === 2'd1 && done === 1'b0, "sumando cero no retorno a LOAD");
    repeat (3) begin
      @(negedge clk);
      check(uut.state === 2'd1 && acc === 6'd0 && uut.counter === 5'd0 && done === 1'b0,
            "espera en LOAD incorrecta tras interrumpir ADD");
    end
    num_suma = 6;
    @(negedge clk);
    check(uut.state === 2'd2 && acc === 6'd0, "no reinicio tras sumando cero");
    sum_cycle(6, 1, 0); sum_cycle(12, 2, 0);
    sum_cycle(18, 3, 0); sum_cycle(24, 4, 1); finish_operation(24);

    // Caso mas largo por umbral: veinte sumas de 1, sin desbordar el contador.
    begin_operation(15, 2'b11, 4'd1);
    for (sum_index = 1; sum_index <= 20; sum_index = sum_index + 1)
      sum_cycle(sum_index, sum_index, sum_index == 20);
    finish_operation(20);

    $display("PASS accumulator: quince pruebas, modos, espera en LOAD, cancel y done");
    $finish;
  end

  initial begin
    // Un bloqueo o una operacion que no termina debe hacer fallar la prueba.
    #10000;
    $fatal(1, "Timeout accumulator");
  end
endmodule
