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
        // El START ya comenzó antes de entrar a esta tarea.
        // Espera el resto del START y el centro del primer bit de datos.
        #(BIT_PERIOD + BIT_PERIOD / 2);
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

  // Ejecuta una transacción completa: A, B, opcode y resultado.
  task run_uart_test;
    input [7:0] a;
    input [7:0] b;
    input [7:0] opcode;
    input [7:0] expected;
    reg [7:0] received;
    begin
      $display("--- PRUEBA UART: A=0x%h B=0x%h OPCODE=0x%h ---", a, b, opcode);

      send_uart_byte(a);
      #(BIT_PERIOD * 2);
      send_uart_byte(b);
      #(BIT_PERIOD * 2);
      send_uart_byte(opcode);

      receive_uart_byte(received);

      if (received == expected) $display("[RESULTADO]: PASS! (Se recibio 0x%h)\n", received);
      else begin
        $display("[RESULTADO]: FAIL! (Se esperaba 0x%h, se obtuvo 0x%h)\n", expected, received);
        $fatal(1, "La prueba UART fallo para opcode 0x%h", opcode);
      end

      #(BIT_PERIOD * 5);
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

    // ADD, SUB, AND, OR, XOR, NOR, SRL, SRA y opcode invalido.
    run_uart_test(8'h05, 8'h03, 8'h20, 8'h08);
    run_uart_test(8'h0F, 8'h06, 8'h22, 8'h09);
    run_uart_test(8'hF0, 8'h0F, 8'h24, 8'h00);
    run_uart_test(8'hF0, 8'h0F, 8'h25, 8'hFF);
    run_uart_test(8'hF0, 8'h0F, 8'h26, 8'hFF);
    run_uart_test(8'hF0, 8'h0F, 8'h27, 8'h00);
    run_uart_test(8'h80, 8'h02, 8'h02, 8'h20);
    run_uart_test(8'h80, 8'h02, 8'h03, 8'hE0);
    run_uart_test(8'hAA, 8'h55, 8'h00, 8'h00);

    #(BIT_PERIOD * 10);
    $display("=======================================================");
    $display("             FIN DE SIMULACION COMPLETA                ");
    $display("=======================================================\n");
    $finish;
  end

endmodule
