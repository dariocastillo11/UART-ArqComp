`timescale 1ns / 1ps

module tb_top_uart_alu ();

  // Parámetros
  parameter NB_DATA    = 8;
  parameter NB_OP_CODE = 6;

  // Período de reloj de 100 MHz (10 ns), igual que la Basys 3
  localparam CLK_PERIOD = 10;

  // Tiempo de 1 bit serie: 326 ticks * 16 sub-ticks * 10 ns = 52.16 us
  localparam BIT_PERIOD = 326 * 16 * CLK_PERIOD;

  // Señales de prueba (Entradas del DUT -> reg, Salidas del DUT -> wire)
  reg clk;
  reg reset;
  reg rx;
  wire tx;
  wire debug_tx;
  wire debug_tick;

  // Variables internas del Testbench
  reg [NB_DATA-1:0] rx_byte_to_send;
  reg [NB_DATA-1:0] tx_byte_received;
  integer i;

  // Instancia del Top-Level (DUT - Device Under Test)
  top_uart_alu #(
      .NB_DATA   (NB_DATA),
      .NB_OP_CODE(NB_OP_CODE)
  ) u_dut (
      .clk       (clk),
      .reset     (reset),
      .rx        (rx),
      .tx        (tx),
      .debug_tx  (debug_tx),
      .debug_tick(debug_tick)
  );

  // 1. Generación del reloj de 100 MHz
  always begin
    clk = 1'b0;
    #(CLK_PERIOD / 2);
    clk = 1'b1;
    #(CLK_PERIOD / 2);
  end

  always @(posedge clk) begin
    if (u_dut.u_uart_rx.rx_done_tick)
      $display("[%0t ns] RX done: 0x%h", $time, u_dut.u_uart_rx.dout);
    if (u_dut.u_interface.tx_start)
      $display("[%0t ns] TX start: 0x%h", $time, u_dut.u_interface.tx_data);
  end

  // 2. Tarea para enviar un byte completo por el pin RX (Simula la PC)
  task send_uart_byte;
    input [7:0] data;
    begin
      $display("[%0t ns] [TB -> FPGA] Enviando Byte: 0x%h (%0d)", $time, data, data);

      // Bit de START (0)
      rx = 1'b0;
      #(BIT_PERIOD);

      // 8 Bits de Datos (LSB a MSB)
      for (i = 0; i < 8; i = i + 1) begin
        rx = data[i];
        #(BIT_PERIOD);
      end

      // Bit de STOP (1)
      rx = 1'b1;
      #(BIT_PERIOD);

      $display("[%0t ns] [TB -> FPGA] Byte enviado correctamente.", $time);
    end
  endtask

  // 3. Tarea para recibir y capturar un byte del pin TX (Simula la respuesta de la FPGA)
  task receive_uart_byte;
    output [7:0] data_out;
    begin
      // Espera la caída a 0 del Bit de START
      if (tx !== 1'b0) begin
        @(negedge tx);
        // Avanza al centro del bit de START y luego al centro de D0.
        #(BIT_PERIOD / 2);
        #(BIT_PERIOD);
      end else begin
        // El start comenzó mientras se transmitía el último bit de RX.
        // En este punto estamos aproximadamente en su centro.
        #(BIT_PERIOD / 2);
      end
      $display("[%0t ns] [FPGA -> TB] Detectado Bit de START en TX.", $time);

      // Muestrea los 8 bits de datos
      for (i = 0; i < 8; i = i + 1) begin
        data_out[i] = tx;
        #(BIT_PERIOD);
      end

      $display("[%0t ns] [FPGA -> TB] Resultado Recibido desde la ALU: 0x%h (%0d)", $time,
               data_out, data_out);
    end
  endtask

  // 4. Secuencia Principal de Estímulos
  initial begin
    $dumpfile("tb_top_uart_alu.vcd");
    $dumpvars(0, tb_top_uart_alu);

    // Inicialización
    rx    = 1'b1; // Línea serie en reposo a 1
    reset = 1'b1;  // Botón Basys 3 activo en alto
    #(100);

    reset = 1'b0;  // Quita el Reset
    #(200);
    $display("\n=======================================================");
    $display("   INICIO DE SIMULACION COMPLETA TP2 (UART + ALU)   ");
    $display("=======================================================\n");

    // -------------------------------------------------------------
    // PRUEBA 1: Suma (ADD -> Opcode 0x20 / 6'b100000)
    // Operando A = 5  (0x05)
    // Operando B = 3  (0x03)
    // Esperado   = 8  (0x08)
    // -------------------------------------------------------------
    $display("--- PRUEBA 1: SUMA (5 + 3 = 8) ---");
    send_uart_byte(8'h05);  // Operando A
    #(BIT_PERIOD * 2);

    send_uart_byte(8'h03);  // Operando B
    #(BIT_PERIOD * 2);

    send_uart_byte(8'h20);  // Opcode ADD (6'b100000)

    // Captura y verifica la respuesta que envía la FPGA
    receive_uart_byte(tx_byte_received);

    if (tx_byte_received == 8'h08)
      $display("[RESULTADO]: PASS! (Suma correcta: %0d)\n", tx_byte_received);
    else begin
      $display("[RESULTADO]: FAIL! (Se esperaba 8, se obtuvo %0d)\n", tx_byte_received);
      $fatal(1, "La prueba de suma fallo");
    end

    #(BIT_PERIOD * 5);

    // -------------------------------------------------------------
    // PRUEBA 2: Resta (SUB -> Opcode 0x22 / 6'b100010)
    // Operando A = 15 (0x0F)
    // Operando B = 6  (0x06)
    // Esperado   = 9  (0x09)
    // -------------------------------------------------------------
    $display("--- PRUEBA 2: RESTA (15 - 6 = 9) ---");
    send_uart_byte(8'h0F);  // Operando A
    #(BIT_PERIOD * 2);

    send_uart_byte(8'h06);  // Operando B
    #(BIT_PERIOD * 2);

    send_uart_byte(8'h22);  // Opcode SUB (6'b100010)

    // Captura la respuesta
    receive_uart_byte(tx_byte_received);

    if (tx_byte_received == 8'h09)
      $display("[RESULTADO]: PASS! (Resta correcta: %0d)\n", tx_byte_received);
    else begin
      $display("[RESULTADO]: FAIL! (Se esperaba 9, se obtuvo %0d)\n", tx_byte_received);
      $fatal(1, "La prueba de resta fallo");
    end

    #(BIT_PERIOD * 10);
    $display("=======================================================");
    $display("             FIN DE SIMULACION COMPLETA                ");
    $display("=======================================================\n");
    $finish;
  end

endmodule
