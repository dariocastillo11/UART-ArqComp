`timescale 1ns / 1ps
//=============================================================================
// Testbench autoverificable para la ALU
//   - Estímulos aleatorios + modelo de referencia independiente
//   - Casos dirigidos de borde
//   - Barrido exhaustivo (si el tamaño del bus lo permite)
//=============================================================================

module tb_ALU;

//------------ PARÁMETROS DEL TEST ------
    localparam NB_DATA      = 8;
    localparam NB_OP_CODE   = 6;
    localparam N_RANDOM     = 2000;   // vectores aleatorios con opcode válido
    localparam N_INVALID    = 200;    // vectores con opcode arbitrario (prueba el default)
    localparam DELAY        = 10;     // ns entre estímulos

    localparam N_OPS        = 8;

//------------ SEÑALES ------------------
    reg  [NB_DATA-1:0]      tb_data_a;
    reg  [NB_DATA-1:0]      tb_data_b;
    reg  [NB_OP_CODE-1:0]   tb_op;
    wire [NB_DATA-1:0]      tb_res;

    reg  [NB_OP_CODE-1:0]   valid_ops [0:N_OPS-1];

    integer errors  = 0;
    integer checks  = 0;
    integer i, j, k;

//------------ DUT ----------------------
    ALU
    #(
        .NB_DATA    (NB_DATA),
        .NB_OP_CODE (NB_OP_CODE)
    )
    u_alu
    (
        .i_data_a   (tb_data_a),
        .i_data_b   (tb_data_b),
        .i_op       (tb_op),
        .o_res      (tb_res)
    );

//-----------------------------------------------------------------------------
// Modelo de referencia (golden model)
// Escrito con if/else en lugar de case a propósito: si el DUT y el modelo
// comparten la misma estructura, un error de tipeo se replica en ambos y el
// test no detecta nada.
//-----------------------------------------------------------------------------
    function [NB_DATA-1:0] golden;
        input [NB_DATA-1:0]     a;
        input [NB_DATA-1:0]     b;
        input [NB_OP_CODE-1:0]  op;
        begin
            if      (op == 6'h20) golden = a + b;
            else if (op == 6'h22) golden = a - b;
            else if (op == 6'h24) golden = a & b;
            else if (op == 6'h25) golden = a | b;
            else if (op == 6'h26) golden = a ^ b;
            else if (op == 6'h27) golden = ~(a | b);
            else if (op == 6'h02) golden = a >> b;
            else if (op == 6'h03) golden = $signed(a) >>> b;
            else                  golden = {NB_DATA{1'b0}};
        end
    endfunction

//-----------------------------------------------------------------------------
// Tarea de chequeo: aplica el estímulo, espera y compara
//-----------------------------------------------------------------------------
    task check;
        input [NB_DATA-1:0]     a;
        input [NB_DATA-1:0]     b;
        input [NB_OP_CODE-1:0]  op;
        reg   [NB_DATA-1:0]     expected;
        begin
            tb_data_a = a;
            tb_data_b = b;
            tb_op     = op;
            #DELAY;

            expected = golden(a, b, op);
            checks   = checks + 1;

            if (tb_res !== expected) begin
                errors = errors + 1;
                $display("[ERROR] t=%0t ns | op=%b a=%h b=%h | DUT=%h esperado=%h",
                         $time, op, a, b, tb_res, expected);
            end
        end
    endtask

//-----------------------------------------------------------------------------
// Secuencia principal
//-----------------------------------------------------------------------------
    initial begin
        valid_ops[0] = 6'b100000;  // ADD
        valid_ops[1] = 6'b100010;  // SUB
        valid_ops[2] = 6'b100100;  // AND
        valid_ops[3] = 6'b100101;  // OR
        valid_ops[4] = 6'b100110;  // XOR
        valid_ops[5] = 6'b100111;  // NOR
        valid_ops[6] = 6'b000011;  // SRA
        valid_ops[7] = 6'b000010;  // SRL

        tb_data_a = {NB_DATA{1'b0}};
        tb_data_b = {NB_DATA{1'b0}};
        tb_op     = 6'b000000;
        #DELAY;

        $display("=====================================================");
        $display(" TB ALU | NB_DATA=%0d NB_OP_CODE=%0d", NB_DATA, NB_OP_CODE);
        $display("=====================================================");

        //---------------------------------------------------------------------
        // FASE 1: casos dirigidos de borde
        //---------------------------------------------------------------------
        $display("-- Fase 1: casos dirigidos");

        for (i = 0; i < N_OPS; i = i + 1) begin
            check({NB_DATA{1'b0}}, {NB_DATA{1'b0}}, valid_ops[i]);   // 0 op 0
            check({NB_DATA{1'b1}}, {NB_DATA{1'b1}}, valid_ops[i]);   // todos unos
            check({NB_DATA{1'b1}}, {NB_DATA{1'b0}}, valid_ops[i]);
            check({NB_DATA{1'b0}}, {NB_DATA{1'b1}}, valid_ops[i]);
        end

        // Overflow / wrap-around de la suma
        check({NB_DATA{1'b1}}, {{(NB_DATA-1){1'b0}}, 1'b1}, 6'b100000);  // -1 + 1
        // Borrow de la resta
        check({NB_DATA{1'b0}}, {{(NB_DATA-1){1'b0}}, 1'b1}, 6'b100010);  // 0 - 1

        // Sign extension del SRA: 0x80 (MSB en 1) desplazado
        for (i = 0; i <= NB_DATA; i = i + 1) begin
            check({1'b1, {(NB_DATA-1){1'b0}}}, i[NB_DATA-1:0], 6'b000011);  // SRA
            check({1'b1, {(NB_DATA-1){1'b0}}}, i[NB_DATA-1:0], 6'b000010);  // SRL
        end

        // Shift mayor o igual al ancho del bus
        check({NB_DATA{1'b1}}, NB_DATA*2, 6'b000011);
        check({NB_DATA{1'b1}}, NB_DATA*2, 6'b000010);

        //---------------------------------------------------------------------
        // FASE 2: estímulos aleatorios con opcodes válidos
        //---------------------------------------------------------------------
        $display("-- Fase 2: %0d vectores aleatorios (opcodes validos)", N_RANDOM);

        for (i = 0; i < N_RANDOM; i = i + 1) begin
            j = {$random} % N_OPS;
            check($random, $random, valid_ops[j]);
        end

        //---------------------------------------------------------------------
        // FASE 3: opcodes arbitrarios (verifica la rama default)
        //---------------------------------------------------------------------
        $display("-- Fase 3: %0d vectores con opcode arbitrario", N_INVALID);

        for (i = 0; i < N_INVALID; i = i + 1) begin
            check($random, $random, $random);
        end

        //---------------------------------------------------------------------
        // FASE 4: barrido exhaustivo (solo si el espacio es manejable)
        //---------------------------------------------------------------------
        if (NB_DATA <= 6) begin
            $display("-- Fase 4: barrido exhaustivo");
            for (i = 0; i < (1 << NB_DATA); i = i + 1)
                for (j = 0; j < (1 << NB_DATA); j = j + 1)
                    for (k = 0; k < N_OPS; k = k + 1)
                        check(i[NB_DATA-1:0], j[NB_DATA-1:0], valid_ops[k]);
        end
        else begin
            $display("-- Fase 4: omitida (NB_DATA=%0d, espacio demasiado grande)", NB_DATA);
        end

        //---------------------------------------------------------------------
        // Reporte final
        //---------------------------------------------------------------------
        $display("=====================================================");
        $display(" Chequeos realizados : %0d", checks);
        $display(" Errores detectados  : %0d", errors);
        if (errors == 0)
            $display(" >>> TEST PASSED <<<");
        else
            $display(" >>> TEST FAILED <<<");
        $display("=====================================================");

        $finish;
    end

//------------ WATCHDOG -----------------
    initial begin
        #10_000_000;
        $display(">>> TIMEOUT: la simulacion no termino a tiempo <<<");
        $finish;
    end

endmodule