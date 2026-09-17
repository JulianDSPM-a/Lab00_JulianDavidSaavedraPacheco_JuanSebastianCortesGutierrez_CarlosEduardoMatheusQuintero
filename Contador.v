module Contador(
    input wire clk,
    input wire reset,
    input wire start,
    input wire cancel,
    input wire [1:0] num_veces,
    input wire [3:0] num_suma,

    output reg [5:0] acc,
    output reg done
);


reg [2:0] counter;

// Declaración de estado actual y estado siguiente
reg [1:0] next_state;
reg [1:0] state; 


// Codificación de los estados de la FMS

parameter [1:0] IDLE = 2'b00;
parameter [1:0] LOAD = 2'b01;
parameter [1:0] ADD = 2'b10;
parameter [1:0] DONE = 2'b11;


// Configuración de reset y cambio de estado en cada ciclo de reloj

always @(posedge clk or posedge reset) begin

    if (reset) begin
        state <= IDLE;
        acc <= 0;
        counter <= 0;
    end else begin

        state <= next_state;

    end else begin

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
                // Mantener el valor de acc y counter en DONE
            end
            default: begin
                // No hacer nada en otros estados
            end
        endcase
    end 
end

// Bloque combinacional para la lógica de transición de estados y salida de la FMS

always @(*) begin
    
    done = 0;
    
    case (state)

        IDLE: begin
            if (start) begin
                next_state = LOAD;
            end else begin
                next_state = IDLE;
            end
        end

        LOAD: begin
            next_state = ADD;
        end

        ADD: begin

            if (cancel) begin
                next_state = LOAD;

            end else begin
                if (num_veces == 2'b00) begin
                    if (acc + num_suma >= 20) begin
                        next_state = DONE;
                    end else begin
                        next_state = ADD;
                    end
                end else begin
                    if (counter == num_veces + 1)begin
                        next_state = DONE;
                    end else begin
                        next_state = ADD;
                    end
                end
            end
        end

        DONE: begin
            done = 1;
            next_state = IDLE;
            end

        default: begin
            next_state = IDLE;
        end
    endcase
end


endmodule