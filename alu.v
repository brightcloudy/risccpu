`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:26:43 01/22/2015 
// Design Name: 
// Module Name:    alu 
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
module alu(
    input [4:0] aop,
    input [7:0] x,
    input [7:0] y,
	 input [7:0] s,
    output reg [7:0] o,
	 output reg [7:0] os
    );

wire [7:0] sum;
wire sumzero;
wire [7:0] diff;
wire diffzero;
wire equal;
wire [7:0] lshifted;
wire [7:0] lshsum;
assign sum = x + y;
assign sumzero = (sum == 8'd0);
assign diff = x - y;
assign diffzero = (diff == 8'd0);
assign equal = (x == y) ? 1'b1 : 1'b0;
assign lshifted = {x[7:1], 0};
assign lshsum = lshifted + y;


parameter [4:0] RETX = 5'b00000;
parameter [4:0] RETY = 5'b00001;
parameter [4:0] ADD = 5'b00010;
parameter [4:0] SUB = 5'b00011;
parameter [4:0] CMP = 5'b00100;
parameter [4:0] LSHIFT = 5'b00101;

always @(aop or x or y) begin
	case (aop)
		RETX: begin
			o = x;
			os = s;
		end
		RETY: begin
			o = y;
			os = s;
		end
		ADD: begin
			o = sum;
			os = {s[7:2], sumzero, s[0]};
		end
		SUB: begin
			o = diff;
			os = {s[7:2], diffzero, s[0]};
		end
		CMP: begin
			o = x;
			os = {s[7:1], equal};
		end
		LSHIFT: begin
			o = lshsum;
			os = s;
		end
		default: begin
			o = x;
			os = s;
		end
	endcase
end
endmodule
