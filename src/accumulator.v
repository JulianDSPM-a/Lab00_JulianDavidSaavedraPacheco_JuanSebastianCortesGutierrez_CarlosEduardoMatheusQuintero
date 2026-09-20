`timescale 1ns/1ps

// Los modos 00 y 11 acumulan hasta alcanzar o superar 20; 01 y 10
// realizan tres y cuatro sumas. Las entradas se consultan durante la operacion,
// por lo que deben mantenerse estables si no se quiere cambiar su criterio.
module accumulator(
    input wire clk,
    input wire reset,
    input wire start,
    input wire cancel,
    input wire [1:0] num_veces,
    input wire [3:0] num_suma,
    output reg [5:0] acc,
    output reg done
);

// counter cuenta las sumas realizadas; acc conserva el resultado acumulado.
// Cinco bits permiten contar las veinte sumas necesarias cuando num_suma = 1.
reg [4:0] counter;
reg [1:0] next_state;
reg [1:0] state;

parameter [1:0] IDLE = 2'b00;
parameter [1:0] LOAD = 2'b01;
parameter [1:0] ADD = 2'b10;
parameter [1:0] DONE = 2'b11;

// Registro de estado con reset asincrono. El datapath se reinicia en otro bloque.
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end

// Logica combinacional de transicion y salida done.
// start solo se atiende en IDLE; done se activa unicamente en DONE.
always @(*) begin
    done = 0;

    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD;
            end
            else begin
                next_state = IDLE;
            end
        end

        LOAD: begin
            // Se mantiene el datapath en cero hasta recibir un sumando valido.
            if (num_suma == 0) next_state = LOAD;
            else next_state = ADD;
        end

        ADD: begin
            // La cancelacion tiene prioridad incluso si esta suma iba a ser la ultima.
            if (cancel) begin
                next_state = LOAD;
            end
            else if (num_suma == 0) begin
                // Si el sumando pasa a cero durante la operacion, se reinicia
                // la carga y se espera un nuevo valor, sin generar done.
                next_state = LOAD;
            end
            else begin
                if (num_veces == 2'b00 || num_veces == 2'b11) begin
                    // Se anticipa el resultado: la ultima suma se registra en el
                    // mismo flanco que lleva a DONE. Comparar solo acc sumaria de mas.
                    if (acc + num_suma >= 20) begin
                        next_state = DONE;
                    end
                    else begin
                        next_state = ADD;
                    end
                end
                else begin
                    // Falta la suma del proximo flanco para completar num_veces + 2.
                    if (counter == num_veces + 1) begin
                        next_state = DONE;
                    end
                    else begin
                        next_state = ADD;
                    end
                end
            end
        end

        // Se permanece un ciclo en DONE y luego se espera una nueva solicitud.
        DONE: begin
            done = 1;
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

// Datapath: las asignaciones no bloqueantes usan el estado anterior al flanco.
// Por eso ADD tambien suma al pasar a DONE o LOAD. Si hubo cancelacion,
// el borrado se realiza un flanco despues, cuando el estado previo ya es LOAD.
always @(posedge clk or posedge reset) begin
    if (reset) begin
        acc <= 0;
        counter <= 0;
    end
    else begin
        case (state)
            LOAD: begin
                acc <= 0;
                counter <= 0;
            end
            ADD: begin
                acc <= acc + num_suma;
                counter <= counter + 1;
            end
            DONE: begin
                // Mantener el valor de acc y counter en DONE.
            end
            default: begin
                // Sin asignacion, los registros conservan su valor mientras se espera.
            end
        endcase
    end
end

endmodule
