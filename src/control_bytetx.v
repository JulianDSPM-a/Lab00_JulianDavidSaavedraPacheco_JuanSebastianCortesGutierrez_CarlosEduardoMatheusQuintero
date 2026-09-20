`timescale 1ns/1ns

// Envia ocho bits, empezando por el menos significativo (LSB).
// Es un envio de datos sin bits de inicio o parada de un protocolo UART.
module control_bytetx(
    input clk,
    input rst,
    input [7:0] data_in,
    input start,
    output reg done,
    output reg busy,
    output reg tx
);

// Cada bit dura esta cantidad de ciclos. El contador de 3 bits permite de 1 a 8.
parameter CLKS_PER_BIT = 4;

// Los registros next_* preparan los valores que se guardaran en el proximo flanco.
// bit_count identifica el bit enviado; tick_cnt mide su tiempo de permanencia.
reg next_busy;
reg [1:0] state, next_state;
reg [7:0] shift_reg, next_shift_reg;
reg [3:0] bit_count, next_bit_count;
reg [2:0] tick_cnt, next_tick_cnt;

parameter S_IDLE = 2'b00;
parameter S_LOAD = 2'b01;
parameter S_BIT_HOLD = 2'b10;
parameter S_DONE = 2'b11;

// Unico bloque que escribe los registros, incluido busy. El reset asincrono
// aborta cualquier envio, limpia los contadores y devuelve el estado a reposo.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;
        busy <= 1'b0;
        bit_count <= 4'd0;
        tick_cnt <= 3'd0;
        shift_reg <= 8'd0;
    end
    else begin
        state <= next_state;
        bit_count <= next_bit_count;
        tick_cnt <= next_tick_cnt;
        shift_reg <= next_shift_reg;
        busy <= next_busy;
    end
end

// Valores por defecto: linea en reposo alto, done desactivado y datos conservados.
// Cada estado modifica solo los valores necesarios para su operacion.
always @(*) begin
    next_state = state;
    done = 1'b0;
    // busy tiene un unico controlador secuencial; aqui se calcula su proximo valor.
    next_busy = 1'b0;
    tx = 1'b1;
    next_bit_count = bit_count;
    next_tick_cnt = tick_cnt;
    next_shift_reg = shift_reg;

    case (state)
        // Al aceptar start, busy se activara junto con la entrada a S_LOAD.
        S_IDLE: begin
            done = 1'b0;
            if (start) begin
                next_state = S_LOAD;
                next_busy = 1'b1;
            end
            else begin
                tx = 1'b1;
                next_state = S_IDLE;
            end
        end

        // El byte se captura al salir de S_LOAD; data_in debe ser valido hasta entonces.
        S_LOAD: begin
            next_busy = 1'b1;
            next_bit_count = 4'd0;
            next_tick_cnt = 3'd0;
            next_shift_reg = data_in;
            next_state = S_BIT_HOLD;
        end

        // Se mantiene el mismo bit hasta completar CLKS_PER_BIT ciclos.
        S_BIT_HOLD: begin
            next_busy = 1'b1;
            tx = shift_reg[0];
            if (tick_cnt != CLKS_PER_BIT - 1) begin
                next_tick_cnt = tick_cnt + 3'd1;
                next_state = S_BIT_HOLD;
            end
            // El bit 7 es el ultimo. busy bajara al entrar en S_DONE,
            // justo cuando done indique que el byte ya se termino de enviar.
            else if (bit_count == 7) begin
                next_state = S_DONE;
                next_busy = 1'b0;
            end
            else begin
                next_bit_count = bit_count + 4'd1;
                // El siguiente bit pasa a la posicion cero, que alimenta tx.
                next_shift_reg = {1'b0, shift_reg[7:1]};
                next_tick_cnt = 3'd0;
                next_state = S_BIT_HOLD;
            end
        end

        // Pulso de finalizacion de un ciclo; tx vuelve al nivel de reposo.
        S_DONE: begin
            done = 1'b1;
            next_state = S_IDLE;
            next_busy = 1'b0;
        end

        default: begin
            next_state = S_IDLE;
        end
    endcase
end

endmodule
