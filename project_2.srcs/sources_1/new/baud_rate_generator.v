module baud_rate_generator
#(
    parameter integer N_MOD  = 326, // 100MHz / (19200 * 16), redondeado
    parameter integer NB_MOD = 9     // Cantidad de bits para representar N_MOD
)
(
    input  wire clk,
    input  wire reset,
    output wire max_tick 
);

    reg  [NB_MOD-1:0] count_reg; // 7:0  de 0 a 255 maximo  REGISTROO
    wire [NB_MOD-1:0] count_next;// 7:0  de 0 a 255 maximo.  CABLE?



    // Bloque secuencial para almacenar el contador
    always @(posedge clk or posedge reset) begin
        if (reset)
            count_reg <= {NB_MOD{1'b0}}; //pongo en 0 8 veces el count_reg. si apreto el reset 
        else
            count_reg <= count_next; // pongo el valor de count_next en count_reg. lo hace en cada ciclo de reloj de mi fpga.
    end

    // Lógica combinacional del siguiente estado y salida
    assign count_next = (count_reg == (N_MOD - 1)) ? {NB_MOD{1'b0}} : count_reg + 1'b1;
                // si es 163-1 osea si     es 162 . 
                                                  // si cumple pongo 0 8veces el count_reg
                                                  // si no cumple pongo count_reg + 1

    assign max_tick   = (count_reg == (N_MOD - 1)) ? 1'b1 : 1'b0;
    // max_tick seria una señal pero solo esta en 1 ccuando llega a 163 . el resto 
    // del tiempo esta en 0. es como un pulso que dura 1 ciclo de reloj de mi fpga.
// ES UNA SALIDA

endmodule
// count next va aumentando en cada ciclo de reloj de mi fpga. una vez 
// que conto 162 resetea el count_reg y pone en 1 el max_tick