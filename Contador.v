module Contador (
    input wire clk,
    input wire reset,
    input wire start,
    input wire cancel,
    input wire [1:0] num_veces,
    input wire [3:0] num_suma,

    output reg [5:0] acc,
    output reg done
);

    // =========================================================
    // 1. DATAPATH (Ruta de Datos)
    // =========================================================
    reg [2:0] counter;
    
    // Señales de Control (FSM -> Datapath)
    wire clr_acc_cnt;
    wire en_acc_cnt;

    // Señales de Estatus de 1 bit (Datapath -> FSM)
    wire mode_zero  = (num_veces == 2'b00);
    wire comp_ge_20 = (acc + num_suma >= 6'd20);
    wire count_done = (counter == num_veces + 3'd1);

    // Registros del Datapath
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            acc     <= 6'd0;
            counter <= 3'd0;
        end else if (clr_acc_cnt) begin
            acc     <= 6'd0;
            counter <= 3'd0;
        end else if (en_acc_cnt) begin
            acc     <= acc + num_suma;
            counter <= counter + 3'd1;
        end
    end

    // =========================================================
    // 2. CONTROLADOR (FSM Pura)
    // =========================================================
    parameter IDLE = 2'b00, LOAD = 2'b01, ADD = 2'b10, DONE = 2'b11;
    reg [1:0] state, next_state;

    // Actualización de estado
    always @(posedge clk or posedge reset) begin
        if (reset) state <= IDLE;
        else       state <= next_state;
    end

    // Lógica combinacional de control y estado siguiente
    reg clr_acc_cnt_reg, en_acc_cnt_reg;
    assign clr_acc_cnt = clr_acc_cnt_reg;
    assign en_acc_cnt  = en_acc_cnt_reg;

    always @(*) begin
        next_state      = state;
        clr_acc_cnt_reg = 1'b0;
        en_acc_cnt_reg  = 1'b0;
        done            = 1'b0;

        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end

            LOAD: begin
                clr_acc_cnt_reg = 1'b1;
                next_state      = ADD;
            end

            ADD: begin
                en_acc_cnt_reg = 1'b1;
                if (cancel) begin
                    next_state = LOAD;
                end else if ((mode_zero && comp_ge_20) || (!mode_zero && count_done)) begin
                    next_state = DONE;
                end else begin
                    next_state = ADD;
                end
            end

            DONE: begin
                done       = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule