module interface_circuit #(
    parameter NB_DATA    = 8,
    parameter NB_OP_CODE = 6
) (
    input  wire                  clk,
    input  wire                  reset,
    // Conexión con UART RX
    input  wire [   NB_DATA-1:0] rx_data,
    input  wire                  rx_done,
    // Conexión con UART TX
    output reg  [   NB_DATA-1:0] tx_data,
    output reg                   tx_start,
    input  wire                  tx_done,
    // Conexión con la ALU (TP1)
    output reg  [   NB_DATA-1:0] o_alu_a,
    output reg  [   NB_DATA-1:0] o_alu_b,
    output reg  [NB_OP_CODE-1:0] o_alu_op,
    input  wire [   NB_DATA-1:0] i_alu_res,
    output wire [   NB_DATA-1:0] debug_result
);

  localparam [2:0]
        WAIT_A    = 3'b000,
        WAIT_B    = 3'b001,
        WAIT_OP   = 3'b010,
        CALC_SEND = 3'b011,
        SEND      = 3'b100,
        WAIT_TX   = 3'b101;

  reg [2:0] state_reg, state_next;
  reg [NB_DATA-1:0] reg_a, reg_a_next;
  reg [NB_DATA-1:0] reg_b, reg_b_next;
  reg [NB_OP_CODE-1:0] reg_op, reg_op_next;
  reg [NB_DATA-1:0] result_reg, result_next;
  reg [NB_DATA-1:0] tx_payload_reg, tx_payload_next;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state_reg      <= WAIT_A;
      reg_a          <= {NB_DATA{1'b0}};
      reg_b          <= {NB_DATA{1'b0}};
      reg_op         <= {NB_OP_CODE{1'b0}};
      result_reg     <= {NB_DATA{1'b0}};
      tx_payload_reg <= {NB_DATA{1'b0}};
    end else begin
      state_reg      <= state_next;
      reg_a          <= reg_a_next;
      reg_b          <= reg_b_next;
      reg_op         <= reg_op_next;
      result_reg     <= result_next;
      tx_payload_reg <= tx_payload_next;
    end
  end

  always @(*) begin
    state_next      = state_reg;
    reg_a_next      = reg_a;
    reg_b_next      = reg_b;
    reg_op_next     = reg_op;
    result_next     = result_reg;
    tx_payload_next = tx_payload_reg;
    tx_data         = tx_payload_reg;
    tx_start        = 1'b0;

    case (state_reg)
      WAIT_A: begin
        if (rx_done) begin
          reg_a_next = rx_data;
          state_next = WAIT_B;
        end
      end

      WAIT_B: begin
        if (rx_done) begin
          reg_b_next = rx_data;
          state_next = WAIT_OP;
        end
      end

      WAIT_OP: begin
        if (rx_done) begin
          reg_op_next = rx_data[NB_OP_CODE-1:0];
          state_next  = CALC_SEND;
        end
      end

      CALC_SEND: begin
        result_next = i_alu_res;
        tx_payload_next = i_alu_res;
        state_next = SEND;
      end

      SEND: begin
        tx_start   = 1'b1;
        state_next = WAIT_TX;
      end

      WAIT_TX: begin
        if (tx_done) begin
          state_next = WAIT_A;  // Vuelve a esperar una nueva transacción
        end
      end

      default: state_next = WAIT_A;
    endcase
  end

  // Conexión constante hacia las entradas de la ALU
  always @(*) begin
    o_alu_a  = reg_a;
    o_alu_b  = reg_b;
    o_alu_op = reg_op;
  end

  assign debug_result = result_reg;

endmodule
