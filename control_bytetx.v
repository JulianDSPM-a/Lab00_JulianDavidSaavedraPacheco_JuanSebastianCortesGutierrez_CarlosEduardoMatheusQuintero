module control_bytetx(
    input clk,
    input rst,
    input [7:0] data_in,
    input start,
    output reg done,
    output reg busy,
    output reg tx
);

parameter CLKS_PER_BIT = 4;

reg next_busy;
reg [1:0] state, next_state;
reg [7:0] shift_reg, next_shift_reg;
reg [3:0] bit_count, next_bit_count;
reg [2:0] tick_cnt, next_tick_cnt;

parameter S_IDLE = 2'b00;
parameter S_LOAD = 2'b01;
parameter S_BIT_HOLD = 2'b10;
parameter S_DONE = 2'b11;

always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
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

always @(*) begin
    next_state = state;
    done = 1'b0;
    next_busy = busy;
    tx = 1'b1;
    next_bit_count = bit_count;
    next_tick_cnt = tick_cnt;
    next_shift_reg = shift_reg;

    case (state)

        S_IDLE:
        begin
            done = 1'b0;
        if (start) begin
            next_state = S_LOAD;
        end
        else begin
            busy = 1'b0;
            tx = 1'b1;
            next_state = S_IDLE;
        end
        end

        S_LOAD:
        begin
            next_busy = 1'b1;
            next_bit_count = 4'd0;
            next_tick_cnt = 3'd0;
            next_shift_reg = data_in;
            next_state = S_BIT_HOLD;    
        end 

        S_BIT_HOLD:
        begin
            tx = shift_reg[0];
            if (tick_cnt != CLKS_PER_BIT - 1)
            begin
                next_tick_cnt = tick_cnt + 3'd1;
                next_state = S_BIT_HOLD;
            end
            else
                if (bit_count == 7)
                begin
                    next_state = S_DONE;
                end
                else
                begin
                    next_bit_count = bit_count + 4'd1;
                    next_shift_reg = {1'b0, shift_reg[7:1]};
                    next_tick_cnt = 3'd0;
                    next_state = S_BIT_HOLD;
                end
        end
        

        S_DONE: 
        begin
            done = 1'b1;
            next_state = S_IDLE;
            next_busy = 1'b0;
        end

        default:
        begin
            next_state = S_IDLE;
        end
    endcase
end



endmodule