`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/26/2026 06:19:00 PM
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ALU #(
    //------------- PARÁMETROS ------------------
    parameter NB_DATA    = 8,  // Tamaño del bus de datos
    parameter NB_OP_CODE = 6   // Número de bits del código de operación

) (
    //------------ INPUTS -------------------
    input  wire [   NB_DATA     -1:0] i_data_a,
    input  wire [   NB_DATA     -1:0] i_data_b,
    input  wire [NB_OP_CODE     -1:0] i_op,
    //------------ OUTPUTS ------------------
    output wire [    NB_DATA    -1:0] o_res
);

  //------------ CÓDIGOS DE OPERACIÓN ---------------
  localparam [NB_OP_CODE-1:0] OP_ADD = 6'b100000;
  localparam [NB_OP_CODE-1:0] OP_SUB = 6'b100010;
  localparam [NB_OP_CODE-1:0] OP_AND = 6'b100100;
  localparam [NB_OP_CODE-1:0] OP_OR  = 6'b100101;
  localparam [NB_OP_CODE-1:0] OP_XOR = 6'b100110;
  localparam [NB_OP_CODE-1:0] OP_NOR = 6'b100111;
  localparam [NB_OP_CODE-1:0] OP_SRA = 6'b000011;
  localparam [NB_OP_CODE-1:0] OP_SRL = 6'b000010;

  //-------------- LÓGICA ----------------------------
  reg [NB_DATA-1:0] res;

  always @(*) begin
    case (i_op)
      OP_ADD:  res = i_data_a + i_data_b;
      OP_SUB:  res = i_data_a - i_data_b;
      OP_AND:  res = i_data_a & i_data_b;
      OP_OR:   res = i_data_a | i_data_b;
      OP_XOR:  res = i_data_a ^ i_data_b;
      OP_NOR:  res = ~(i_data_a | i_data_b);
      OP_SRL:  res = i_data_a >> i_data_b;  // lógico: entra 0
      OP_SRA:  res = $signed(i_data_a) >>> i_data_b;  // aritmético: replica el signo
      default: res = {NB_DATA{1'b0}};  // evita latches
    endcase
  end

  assign o_res = res;

endmodule
