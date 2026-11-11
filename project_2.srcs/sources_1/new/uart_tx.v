module uart_tx
#(
    parameter DBIT    = 8,
    parameter SB_TICK = 16
)
(
    input  wire       clk,
    input  wire       reset,
    input  wire       tx_start,
    input  wire       s_tick,
    input  wire [7:0] din,
    output reg        tx_done_tick,
    output wire       tx
);

    localparam [1:0]
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    reg [1:0] state_reg, state_next;
    reg [3:0] s_reg, s_next;
    reg [2:0] n_reg, n_next;
    reg [7:0] b_reg, b_next;
    reg       tx_reg, tx_next;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg     <= 4'b0;
            n_reg     <= 3'b0;
            b_reg     <= 8'b0;
            tx_reg    <= 1'b1; // Línea serie en reposo a nivel alto
        end else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
            tx_reg    <= tx_next;
        end
    end

    always @(*) begin
        state_next   = state_reg;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        tx_next      = tx_reg;
        tx_done_tick = 1'b0;

        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) begin
                    state_next = START;
                    s_next     = 4'b0;
                    b_next     = din;
                end
            end

            START: begin
                tx_next = 1'b0; // Bit de Start
                if (s_tick) begin
                    if (s_reg == 4'd15) begin
                        state_next = DATA;
                        s_next     = 4'b0;
                        n_next     = 3'b0;
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            DATA: begin
                tx_next = b_reg[0]; // Salida del LSB
                if (s_tick) begin
                    if (s_reg == 4'd15) begin
                        s_next = 4'b0;
                        b_next = b_reg >> 1;
                        if (n_reg == (DBIT - 1))
                            state_next = STOP;
                        else
                            n_next = n_reg + 1'b1;
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1; // Bit de Stop
                if (s_tick) begin
                    if (s_reg == (SB_TICK - 1)) begin
                        tx_done_tick = 1'b1;
                        state_next   = IDLE;
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            default: state_next = IDLE;
        endcase
    end

    assign tx = tx_reg;

endmodule
