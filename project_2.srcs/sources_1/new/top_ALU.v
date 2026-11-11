module top_uart_alu #(
    parameter NB_DATA    = 8,
    parameter NB_OP_CODE = 6,
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 19_200,
    parameter integer OVERSAMPLE  = 16
) (
    input wire clk,
    input wire reset,
    input wire rx,
    output wire tx,
    output wire [7:0] led,
    // Salidas de prueba para Osciloscopio
    output wire debug_tx,
    output wire debug_tick
);

  // Señales internas de interconexión
  wire                  tick;
  wire [   NB_DATA-1:0] rx_data;
  wire                  rx_done;
  wire [   NB_DATA-1:0] tx_data;
  wire                  tx_start;
  wire                  tx_done;

  wire [   NB_DATA-1:0] alu_a;
  wire [   NB_DATA-1:0] alu_b;
  wire [NB_OP_CODE-1:0] alu_op;
  wire [   NB_DATA-1:0] alu_res;
  wire [   NB_DATA-1:0] debug_result;
  reg  [          25:0] heartbeat_count;
  reg                   tx_previous;
  wire                  reset_i;

  // El botón central de la Basys 3 es activo en alto.
  assign reset_i = reset;

  // Asignación de salidas para osciloscopio
  assign debug_tx = tx;
  assign debug_tick = tick;

  // Indicadores retenidos para verificar la comunicación en la placa.
  always @(posedge clk or posedge reset_i) begin
    if (reset_i) begin
      heartbeat_count <= 26'b0;
      tx_previous <= 1'b1;
    end else begin
      heartbeat_count <= heartbeat_count + 1'b1;
      tx_previous <= tx;
    end
  end

  // Diagnóstico independiente: muestra la salida combinacional de la ALU.
  assign led = alu_res;

  // División redondeada al entero más cercano:
  // CLK_FREQ_HZ / (BAUD_RATE * OVERSAMPLE).
  localparam integer BAUD_DIV =
        (CLK_FREQ_HZ + ((BAUD_RATE * OVERSAMPLE) / 2)) /
        (BAUD_RATE * OVERSAMPLE);
  localparam integer BAUD_DIV_BITS = (BAUD_DIV > 1) ? $clog2(BAUD_DIV) : 1;

  // 1. Genera un pulso de habilitación UART sin crear un segundo reloj.
  baud_rate_generator #(
      .N_MOD (BAUD_DIV),
      .NB_MOD(BAUD_DIV_BITS)
  ) u_baud_gen (
      .clk     (clk),
      .reset   (reset_i),
      .max_tick(tick)
  );

  // 2. Instancia del Receptor UART
  uart_rx #(
      .DBIT   (NB_DATA),
      .SB_TICK(16)
  ) u_uart_rx (
      .clk         (clk),
      .reset       (reset_i),
      .rx          (rx),
      .s_tick      (tick),
      .rx_done_tick(rx_done),
      .dout        (rx_data)
  );

  // 3. Instancia del Transmisor UART
  uart_tx #(
      .DBIT   (NB_DATA),
      .SB_TICK(16)
  ) u_uart_tx (
      .clk         (clk),
      .reset       (reset_i),
      .tx_start    (tx_start),
      .s_tick      (tick),
      .din         (tx_data),
      .tx_done_tick(tx_done),
      .tx          (tx)
  );

  // 4. Instancia del Circuito de Interfaz
  interface_circuit #(
      .NB_DATA   (NB_DATA),
      .NB_OP_CODE(NB_OP_CODE)
  ) u_interface (
      .clk         (clk),
      .reset       (reset_i),
      .rx_data     (rx_data),
      .rx_done     (rx_done),
      .tx_data     (tx_data),
      .tx_start    (tx_start),
      .tx_done     (tx_done),
      .o_alu_a     (alu_a),
      .o_alu_b     (alu_b),
      .o_alu_op    (alu_op),
      .i_alu_res   (alu_res),
      .debug_result(debug_result)
  );

  // 5. Instancia de la ALU del TP1
  ALU #(
      .NB_DATA   (NB_DATA),
      .NB_OP_CODE(NB_OP_CODE)
  ) u_alu (
      .i_data_a(alu_a),
      .i_data_b(alu_b),
      .i_op    (alu_op),
      .o_res   (alu_res)
  );

endmodule
