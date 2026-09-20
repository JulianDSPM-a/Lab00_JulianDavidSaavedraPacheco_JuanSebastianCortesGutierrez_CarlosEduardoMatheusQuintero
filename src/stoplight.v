`timescale 1ns/1ns

// Semaforo con la secuencia verde, amarillo, rojo y amarillo.
// Cada intervalo se mide en ciclos de reloj, no en tiempo real.
module stoplight(
    input clk,
    input rst,
    output red,
    output yellow,
    output green,
    output reg [2:0] counter
);

// state y counter guardan los valores actuales; next_* calcula los del proximo flanco.
reg [1:0] state, next_state;
reg [2:0] next_counter;

parameter S0 = 2'b00; // Verde durante 5 ciclos.
parameter S1 = 2'b01; // Amarillo antes de rojo, durante 2 ciclos.
parameter S2 = 2'b10; // Rojo durante 4 ciclos.
parameter S3 = 2'b11; // Amarillo antes de verde, durante 2 ciclos.

// El reset es asincrono: vuelve a verde sin esperar un flanco de reloj.
// En funcionamiento normal, ambos registros se actualizan al mismo tiempo.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S0;
        counter <= 3'd0;
    end
    else begin
        state <= next_state;
        counter <= next_counter;
    end
end

// Por defecto se conserva el estado y se cuenta un ciclo mas.
// Al cambiar de luz se reinicia el contador para medir el nuevo intervalo.
always @(*) begin
    next_state = state;
    next_counter = counter + 3'd1;

    case (state)
        // El conteo empieza en cero: 0, 1, 2, 3 y 4 representan cinco ciclos.
        S0: begin
            if (counter == 3'd4) begin
                next_state = S1;
                next_counter = 3'd0;
            end
            else begin
                next_state = S0;
            end
        end
        S1: begin
            if (counter == 3'd1) begin
                next_state = S2;
                next_counter = 3'd0;
            end
            else begin
                next_state = S1;
            end
        end
        S2: begin
            if (counter == 3'd3) begin
                next_state = S3;
                next_counter = 3'd0;
            end
            else begin
                next_state = S2;
            end
        end
        // Este segundo amarillo recuerda que se viene de rojo y se debe ir a verde.
        S3: begin
            if (counter == 3'd1) begin
                next_state = S0;
                next_counter = 3'd0;
            end
            else begin
                next_state = S3;
            end
        end
        default begin
            next_state = S0;
            next_counter = 3'd0;
        end
    endcase
end

// Las luces dependen solo del estado actual. Los dos amarillos comparten salida,
// pero tienen destinos distintos; por eso se representan con estados separados.
assign red = (state == S2);
assign yellow = (state == S1) || (state == S3);
assign green = (state == S0);

endmodule
