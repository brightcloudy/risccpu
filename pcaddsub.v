`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:16:46 01/22/2015 
// Design Name: 
// Module Name:    pcaddsub 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module pcaddsub(
    input [7:0] pc,
    input [7:0] val,
    output wire [7:0] out,
    input as
    );

assign out = (as) ? (pc - val) : (pc + val);
endmodule
