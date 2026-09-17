`timescale 1ns/1ps

module tb_Contador;

    // Entradas del módulo
    reg clk;
    reg reset;
    reg start;
    reg cancel;
    reg [1:0] num_veces;
    reg [3:0] num_suma;

    // Salidas del módulo
    wire [5:0] acc;
    wire done;


    // Instancia del módulo
    Contador uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .cancel(cancel),
        .num_veces(num_veces),
        .num_suma(num_suma),
        .acc(acc),
        .done(done)
    );


    // Generación del reloj
    always begin
        #5 clk = ~clk;
    end


    // Estímulos de prueba
    initial begin

        // Valores iniciales
        clk = 0;
        reset = 1;
        start = 0;
        cancel = 0;
        num_veces = 0;
        num_suma = 0;

        // Generar archivo para GTKWave
        $dumpfile("tb_Contador.vcd");
        $dumpvars(0, tb_Contador);


        // ============================
        // RESET
        // ============================

        #10;
        reset = 0;


        // ============================
        // PRUEBA 1:
        // num_veces = 1
        // Debe sumar 3 veces
        // x = 5
        // Resultado esperado: 15
        // ============================

        num_veces = 2'b01;
        num_suma = 4'd5;

        #10;
        start = 1;

        #10;
        start = 0;

        // Esperar a que termine
        #100;


        // ============================
        // PRUEBA 2:
        // num_veces = 2
        // Debe sumar 4 veces
        // x = 5
        // Resultado esperado: 20
        // ============================

        num_veces = 2'b10;
        num_suma = 4'd5;

        #10;
        start = 1;

        #10;
        start = 0;

        #100;


        // ============================
        // PRUEBA 3:
        // CANCELACIÓN
        //
        // num_veces = 3
        // Debería sumar 5 veces
        // x = 4
        //
        // Pero se cancela
        //
        // Esperado:
        // 0 → 4 → 8 → 12
        //       ↓
        //     CANCEL
        //       ↓
        //      LOAD
        //       ↓
        //      acc = 0
        // ============================

        num_veces = 2'b11;
        num_suma = 4'd4;

        #10;
        start = 1;

        #10;
        start = 0;

        // Dejar que haga algunas sumas
        #30;

        // Activar cancelación
        cancel = 1;

        #10;
        cancel = 0;

        // Esperar para observar el resultado
        #100;


        // ============================
        // PRUEBA 4:
        // num_veces = 0
        // Sumar hasta acc >= 20
        // x = 6
        //
        // Esperado:
        // 0 → 6 → 12 → 18 → 24
        // ============================

        num_veces = 2'b00;
        num_suma = 4'd6;

        #10;
        start = 1;

        #10;
        start = 0;

        #150;


        // Terminar simulación
        $finish;

    end

endmodule