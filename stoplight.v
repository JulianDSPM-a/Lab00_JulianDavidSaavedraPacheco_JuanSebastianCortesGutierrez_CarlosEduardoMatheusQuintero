module stoplight(
    input clk,
    input rst,
    output red,
    output yellow,
    output green,
    output reg [2:0] counter 
);


reg [1:0] state, next_state;
reg [2:0] next_counter; //Declaramos un contador que transfiere la información del contador actual al siguien estado por cada flanco

parameter S0 = 2'b00; // Green
parameter S1 = 2'b01; // Yellow_1
parameter S2 = 2'b10; // Red
parameter S3 = 2'b11; // Yellow_2

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

always @(*) begin
    next_state = state; //Cambios en state o counter activan la lógica combinacional
    next_counter = counter + 3'd1; //Al activar la lógica combinacional, el contador se incrementa en 1, para que al siguiente flanco, se haga este incremento

    case (state)
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

assign red = (state == S2);
assign yellow = (state == S1) || (state == S3);
assign green = (state == S0);


endmodule
