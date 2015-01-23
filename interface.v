`timescale 1ns / 1ps
module interface(
	 //input clkp,
	 //input clkn,
	 input clk,
    input [3:0] buttons,
	 input [3:0] switches,
    output wire [3:0] leds
    );

wire clkmed;
//wire clk;
wire [7:0] pc;
wire [9:0] expc;
wire [15:0] instrin;
wire [7:0] b;
wire [7:0] datain;
wire [7:0] dataout;
wire [7:0] a;
wire [7:0] bsink;
wire [7:0] bsink2;
wire [1:0] page;
wire [2:0] upage;
wire [10:0] expb;
wire wr;
wire [15:0] dummyin;
assign expc = {page, pc};
assign expb = {upage, b};
assign dummyin = {15'd0, switches[1]};

assign leds = a[3:0];

//IBUFDS ibuf (.I(clkp), .IB(clkn), .O(clkmed));
//BUFG bufr (.I(clkmed), .O(clk));

control icontrol (.clk(clk), .instrin(instrin), .pco(pc), .upage(upage), .page(page), .datain(datain), .dataout(dataout), .wr(wr), .bo(b), .ao(a));
bram_tdp #(16,10) program ( .a_clk(clk), .a_wr(switches[0]), .a_addr(expc), .a_din(dummyin), .a_dout(instrin), .b_clk(clk), .b_wr(1'b0), .b_addr(10'b0), .b_din(16'd0), .b_dout(bsink));
bram_user #(8,11) data (.a_clk(clk), .a_wr(wr), .a_addr(expb), .a_din(dataout), .a_dout(datain), .b_clk(clk), .b_wr(switches[1]), .b_addr(dummyin), .b_din(dummyin), .b_dout(bsink2));
endmodule
