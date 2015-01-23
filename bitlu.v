`timescale 1ns / 1ps

module bitlu(
    input [1:0] bop,
    input [7:0] x,
    input [7:0] y,
    output reg [7:0] o
    );

wire [7:0] xorv;
wire [7:0] andv;
wire [7:0] orv;
wire [7:0] nandv;
assign xorv = x ^ y;
assign andv = x & y;
assign orv = x | y;
assign nandv = ~(x & y);

parameter [1:0] AND = 2'b00;
parameter [1:0] OR = 2'b01;
parameter [1:0] XOR = 2'b10;
parameter [1:0] NAND = 2'b11;

always @(bop or x or y) begin
	case (bop)
		AND: o = andv;
		OR: o = orv;
		XOR: o = xorv;
		NAND: o = nandv;
		default: o = andv;
	endcase
end

endmodule
