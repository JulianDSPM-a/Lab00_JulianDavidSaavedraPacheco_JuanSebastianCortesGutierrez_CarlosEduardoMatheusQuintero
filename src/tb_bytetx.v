`timescale 1ns/1ns
`include "control_bytetx.v"
`timescale 1ns/1ns

// Comprueba el envio LSB-first, la duracion de cada bit y las señales de control.
// Tambien interrumpe un envio con reset y comprueba una transmision posterior.
module tb_bytetx;
  parameter CLKS_PER_BIT = 4;
  reg clk, rst, start;
  // recibido reconstruye el byte para compararlo con el dato original.
  reg [7:0] data_in, recibido;
  wire done, busy, tx;
  // Identifica cada envio en las formas de onda y en los mensajes de error.
  integer test_id;

  control_bytetx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
    .clk(clk), .rst(rst), .data_in(data_in), .start(start),
    .done(done), .busy(busy), .tx(tx)
  );

  // Reloj de periodo 10 ns: con CLKS_PER_BIT = 4, cada bit dura 40 ns.
  initial clk = 0;
  always #5 clk = ~clk;

  // Se detiene ante una condicion falsa o indeterminada, indicando el instante.
  task check;
    input condition;
    input [8*120-1:0] message;
    begin
      if (condition !== 1'b1)
        $fatal(1, "FAIL bytetx test=%0d t=%0t: %0s", test_id, $time, message);
    end
  endtask

  // Genera start por un ciclo y espera la carga del byte. Se usa el flanco
  // negativo para que los registros del flanco positivo ya esten actualizados.
  task begin_transmission;
    input integer id;
    input [7:0] value;
    begin
      @(negedge clk);
      check(dut.state === 2'd0 && busy === 1'b0 && done === 1'b0 && tx === 1'b1,
            "reposo incorrecto");
      test_id = id;
      data_in = value;
      start = 1;
      recibido = 0;
      @(negedge clk);
      check(dut.state === 2'd1 && busy === 1'b1 && done === 1'b0 && tx === 1'b1,
            "LOAD o busy incorrectos");
      start = 0;
      @(negedge clk);
      check(dut.state === 2'd2 && dut.shift_reg === value, "carga de byte incorrecta");
      $display("Inicio bytetx test=%0d dato=%h, t=%0t", id, value, $time);
    end
  endtask

  // Recorre los ocho bits y sus ciclos de permanencia, no solo los cambios de tx.
  task send_and_check;
    input integer id;
    input [7:0] value;
    integer bit_index, tick;
    begin
      begin_transmission(id, value);
      // Comprobar cada ciclo de cada bit, incluso entre bits del mismo valor.
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        for (tick = 0; tick < CLKS_PER_BIT; tick = tick + 1) begin
          check(dut.state === 2'd2 && busy === 1'b1 && done === 1'b0,
                "estado, busy o done durante el envio incorrectos");
          check(tx === value[bit_index], "bit serial incorrecto");
          check(dut.bit_count == bit_index, "indice del bit incorrecto");
          check(dut.tick_cnt == tick, "duracion del bit incorrecta");
          check(dut.shift_reg === (value >> bit_index), "desplazamiento incorrecto");
          // Una muestra por bit basta para reconstruirlo; las demas comprueban
          // que la salida se mantiene estable durante todo el intervalo.
          if (tick == 0) recibido[bit_index] = tx;
          @(negedge clk);
        end
      end
      // Al terminar, done debe subir y busy bajar en el mismo ciclo.
      check(recibido === value, "byte reconstruido incorrecto");
      check(dut.state === 2'd3 && done === 1'b1 && busy === 1'b0 && tx === 1'b1,
            "DONE debe activar done y desactivar busy");
      $display("OK bytetx test=%0d enviado=%h recibido=%h busy=0 done=1, t=%0t",
               id, value, recibido, $time);
      @(negedge clk);
      check(dut.state === 2'd0 && done === 1'b0 && busy === 1'b0 && tx === 1'b1,
            "done no duro un ciclo o busy no volvio a reposo");
      repeat (2) @(negedge clk);
    end
  endtask

  initial begin
    // Guarda tambien los contadores y el registro de desplazamiento internos.
    $dumpfile("bytetx.vcd");
    $dumpvars(0, tb_bytetx);
    test_id = 0;
    rst = 1; start = 0; data_in = 0; recibido = 0;
    repeat (2) @(negedge clk);
    check(busy === 1'b0 && done === 1'b0 && tx === 1'b1 && dut.state === 2'd0,
          "reset inicial incorrecto");
    rst = 0;

    // Estos patrones comprueban cambios de nivel y grupos de bits iguales.
    send_and_check(1, 8'hA5);
    send_and_check(2, 8'hF0);
    send_and_check(3, 8'h01);

    // Reset durante una transmision: busy debe caer sin esperar otro posedge.
    begin_transmission(4, 8'h96);
    repeat (3) @(negedge clk);
    #2 rst = 1;
    #1;
    check(busy === 1'b0 && done === 1'b0 && tx === 1'b1 && dut.state === 2'd0,
          "reset durante envio no limpio las salidas");
    check(dut.shift_reg === 8'd0 && dut.bit_count == 0 && dut.tick_cnt == 0,
          "reset durante envio no limpio el datapath");
    repeat (2) @(negedge clk);
    rst = 0;
    $display("OK bytetx test=4: envio abortado por reset, t=%0t", $time);

    // El circuito debe aceptar un nuevo byte despues de abortar el envio anterior.
    send_and_check(5, 8'h3C);
    $display("PASS bytetx: cuatro bytes completos, temporizacion, busy, done y reset");
    $finish;
  end

  initial begin
    // Limite de seguridad para detectar una simulacion que no termina.
    #20000;
    $fatal(1, "Timeout bytetx");
  end
endmodule
