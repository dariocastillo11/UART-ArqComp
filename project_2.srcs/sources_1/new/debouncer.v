`timescale 1ns / 1ps
//=============================================================================
// Sincronizador + antirrebote + detector de flanco.
// Genera un pulso de UN ciclo por cada pulsación del botón.
//=============================================================================

module debouncer
#(
    parameter NB_COUNT = 20      // 2^20 / 100 MHz ~= 10.5 ms
)
(
    input  wire clk,
    input  wire i_btn,
    output wire o_pulse
);

    (* ASYNC_REG = "TRUE" *) reg [1:0] sync;
    reg [NB_COUNT-1:0] count;
    reg btn_stable;
    reg btn_prev;

    // 1) Sincronizador de dos flip-flops (evita metaestabilidad)
    always @(posedge clk)
        sync <= {sync[0], i_btn};

    // 2) Antirrebote: el valor solo se acepta si se mantuvo estable
    always @(posedge clk) begin
        if (sync[1] != btn_stable) begin
            count <= count + 1'b1;
            if (&count) btn_stable <= sync[1];
        end
        else begin
            count <= {NB_COUNT{1'b0}};
        end
    end

    // 3) Detector de flanco ascendente
    always @(posedge clk)
        btn_prev <= btn_stable;

    assign o_pulse = btn_stable & ~btn_prev;

endmodule