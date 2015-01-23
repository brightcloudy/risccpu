`timescale 1ns / 1ps

module control(
    input clk,
    input [15:0] instrin, // data in from prog ram port a
    output wire [7:0] pco, // output addr to prog ram port a
	 input [7:0] datain, // data in from data ram port a
	 output wire [7:0] bo, // output addr to data ram a
    output reg [7:0] dataout, // output data to data ram a
    output reg wr, // write enable to data ram a
	 output reg [1:0] page, // memory page selector
	 output reg [2:0] upage, // user data page selector
	 output wire [7:0] ao // output to status indicators
    );

reg [7:0] a; // register a (accumulator)
reg [7:0] b; // register b (data pointer byte)
reg [7:0] s; // register s (internal alu status)
// status bits: ? ? ? ? ? ? z e
// ? ? ? ? ? ? zero equals
reg [7:0] d; // register d (memory r/w intermediate register)
reg [7:0] pc; // register pc (program counter value)
reg [7:0] file [7:0]; // registers 0-7 (register file)
assign pco = pc; // outwards facing pc is pcv
assign bo = b;
assign ao = a[3:0]; // tap off register 7's low nibble for status indication

reg [4:0] aop; // math alu opcode
reg [7:0] x; // math alu x input
reg [7:0] y; // math alu y input
wire [7:0] o; // math alu output
wire [7:0] os; // math alu status output

alu malu (.aop(aop), .x(x), .y(y), .s(s), .o(o), .os(os));

reg [4:0] raop; // transfer alu opcode
reg [7:0] rx; // transfer alu x input
reg [7:0] ry; // transfer alu y input
wire [7:0] ro; // transfer alu output
wire [7:0] ros; // transfer alu status output

alu ralu (.aop(raop), .x(rx), .y(ry), .s(8'd0), .o(ro), .os(ros));

reg [4:0] faop;
reg [7:0] fx;
reg [7:0] fy;
wire [7:0] fo;
wire [7:0] fos;

alu falu (.aop(faop), .x(fx), .y(fy), .s(8'd0), .o(fo), .os(fos));

reg as; // jump addsub direction
reg [7:0] pcin; // pointer counter in 
reg [7:0] val; // jump value in
wire [7:0] pcos; // addsub output
wire [7:0] pcinc;

pcaddsub pcas (.pc(pcin), .val(val), .as(as), .out(pcos));
assign pcinc = pc + 1'b1;

reg [2:0] state; // internal state machine reg
reg [7:0] fbuf; // op+fil fetch bram buffer
reg [7:0] ibuf; // im fetch bram buffer
reg [7:0] rbuf; // data fetch bram buffer
reg [4:0] op; // opcode reg
reg [2:0] fil; // file reg
reg [7:0] im; // immediate value reg
reg [7:0] filb; // register to store accessed register file for reads

reg [7:0] dcop;
reg [7:0] rbuf2;

initial begin
	a <= 8'd0;
	b <= 8'd0;
	s <= 8'd0;
	d <= 8'd0;
	fbuf <= 8'd0;
	rbuf <= 8'd0;
	pc <= 16'd0;
	state <= 3'b000;
	op <= 8'd0;
	im <= 8'd0;
	dataout <= 8'd0;
	wr <= 1'b0;
end

// cpu opcodes
parameter [4:0] NOP = 5'b00000; // do nothing except increment pc (0x00)
parameter [4:0] LDAL = 5'b00001; // load literal into a (0x08)
parameter [4:0] LDBL = 5'b00010; // load literal into b (0x10)
//parameter [4:0] LDCL = 5'b00011; // load literal into c (0x18)
parameter [4:0] LDXL = 5'b00100; // load literal into reg file x (0x20)
parameter [4:0] LDDL = 5'b00101; // load literal into d (0x28)
parameter [4:0] RJMP = 5'b00110; // relative jump + if file 0 relative jump - if file 1+ (0x30)
parameter [4:0] LDAX = 5'b00111; // load reg file x into a (0x38)
parameter [4:0] LDDA = 5'b01000; // load a into d (0x40)
parameter [4:0] LDAB = 5'b01001; // load b into a (0x48)
//parameter [4:0] LDAC = 5'b01010; // load c into a (0x50)
parameter [4:0] LDDB = 5'b01011; // load value at pointer b into d (0x58)
parameter [4:0] LDAD = 5'b01100; // load d into a (0x60)
parameter [4:0] LDBA = 5'b01101; // load a into b (0x68)
//parameter [4:0] LDCA = 5'b01110; // load a into c (0x70)
parameter [4:0] LDXA = 5'b01111; // load a into reg file x (0x78)
parameter [4:0] LDBD = 5'b10000; // load d into memory at pointer b (0x80)
parameter [4:0] ADDL = 5'b10001; // add literal to a (0x88) 
parameter [4:0] ADDX = 5'b10010; // add reg file x to a (0x90)
parameter [4:0] SUBL = 5'b10011; // subtract literal from a (0x98)
parameter [4:0] SUBX = 5'b10100; // subtract reg file x from a (0xA0)
parameter [4:0] LSHFT = 5'b10101; // left shift and add literal (0xA8)
//parameter [4:0] RSHFT = 5'b10110; // right shift a x bits and add literal (0xB0)
parameter [4:0] CMPAL = 5'b10111; // compare literal to a, sets equal flag (0xB8)
parameter [4:0] LDEAL = 5'b11000; // load literal into a if equal, resets equal flag (0xC0)
parameter [4:0] LDEAX = 5'b11001; // load reg file x into a if equal, resets equal flag (0xC8)
parameter [4:0] UPGE = 5'b11010; // set user page x and set b to literal (0xD0)
parameter [4:0] PPGE = 5'b11011; // jump to program page x and set pc to literal (0xD8)
parameter [4:0] JMPB = 5'b11100; // jump (set pc) to b (0xE0)
parameter [4:0] LDBPC = 5'b11101; // load pc into b (0xE8)
parameter [4:0] RJMPE = 5'b11110; // rel jump + if equal (file = 0) rel jump - if equal (file = 1+) (0xF0)
parameter [4:0] CMPAX = 5'b11111; // compare x to a, sets equal flag (0xF8)

// alu opcodes
parameter [4:0] RETX = 5'b00000;
parameter [4:0] RETY = 5'b00001;
parameter [4:0] ADD = 5'b00010;
parameter [4:0] SUB = 5'b00011;
parameter [4:0] CMP = 5'b00100;
parameter [4:0] LSHIFT = 5'b00101;

parameter [2:0] FETCH = 3'b000;
parameter [2:0] DECODE = 3'b001;
parameter [2:0] EXECUTE = 3'b010;
parameter [2:0] MEMORY = 3'b011;
parameter [2:0] WRITEBACK = 3'b100;

always @(posedge clk) begin
	case (state)
		FETCH: begin
			wr <= 1'b0; // clear possible write from last writeback
			state <= DECODE;
		end
		DECODE: begin
			op <= instrin[15:11];
			dcop <= instrin[15:11];
			fil <= instrin[10:8]; // process incoming instructions
			im <= instrin[7:0];
			filb <= file[instrin[10:8]];
			rbuf <= datain;
			pc <= pcinc; // increment program counter
			state <= EXECUTE; // this stage for prop of decoder logic
		end
		EXECUTE: begin
			rbuf2 <= rbuf;
			state <= WRITEBACK; // this stage for prop of alu
		end
		WRITEBACK: begin
			case (op)
				LDAL: a <= ro; // o is alu result
				LDAX: a <= ro;
				LDAB: a <= ro;
				LDAD: a <= ro;
				LDBL: b <= ro;
				LDBA: b <= ro;
				LDBD: begin
					dataout <= ro;
					wr <= 1'b1;
				end
				LDBPC: b <= ro;
				LDDL: d <= ro;
				LDDA: d <= ro;
				LDDB: d <= ro;
				LDXL: file[fil] <= ro;
				LDXA: file[fil] <= ro;
				CMPAL: s <= os;
				CMPAX: s <= fos;
				ADDL: begin
					a <= o;
					s <= os;
				end
				ADDX: begin
					a <= fo;
					s <= fos;
				end
				SUBL: begin
					a <= o;
					s <= os;
				end
				SUBX: begin
					a <= fo;
					s <= fos;
				end
				LDEAL: begin
					if (os[0]) a <= ro;
					s[0] <= 1'b0;
				end
				LDEAX: begin
					if (os[0]) a <= ro;
					s[0] <= 1'b0;
				end
				RJMP: pc <= pco;
				JMPB: pc <= ro;
				RJMPE: begin
					if (os[0]) pc <= pcos;
					s[0] <= 1'b0;
				end
				LSHFT: a <= o;
				PPGE: begin
					page <= fil[1:0];
					pc <= ro;
				end
				UPGE: begin
					upage <= fil;
					b <= ro;
				end
			endcase
			state <= FETCH;
		end
	endcase
end


always @(dcop or a or b or d or file or im or pc or datain or fil or rbuf) begin
	case (dcop)
		RJMP: begin
			as = fil[0];
			pcin = pc;
			val = im;
		end
		default: begin
			as = 1'b0;
			pcin = pc;
			val = im;
		end
	endcase
	// defaults for all alus to avoid latches
	aop = RETY;
	x = 8'd0;
	y = 8'd0;
	raop = RETY;
	x = 8'd0;
	y = 8'd0;
	faop = RETY;
	x = 8'd0;
	y = 8'd0;
	case (dcop)
		// accumulator load instructions
		LDAL: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		LDAX: begin
			raop = RETY;
			rx = 8'd0;
			ry = filb;
		end
		LDAB: begin
			raop = RETY;
			rx = 8'd0;
			ry = b;
		end
		LDAD: begin
			raop = RETY;
			rx = 8'd0;
			ry = d;
		end
		// register b load instructions
		LDBL: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		LDBA: begin
			raop = RETY;
			rx = 8'd0;
			ry = a;
		end
		LDBPC: begin
			raop = RETY;
			rx = 8'd0;
			ry = pc;
		end
		LDBD: begin
			raop = RETY;
			rx = 8'd0;
			ry = d;
		end
		// pointer d load instructions
		LDDL: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		LDDA: begin
			raop = RETY;
			rx = 8'd0;
			ry = a;
		end
		LDDB: begin
			raop = RETY;
			rx = 8'd0;
			ry = rbuf2;
		end
		// register file load instructions
		LDXL: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		LDXA: begin
			raop = RETY;
			rx = 8'd0;
			ry = a;
		end
		// accumulator add instructions
		ADDL: begin
			aop = ADD;
			x = a;
			y = im;
		end
		ADDX: begin
			faop = ADD;
			fx = a;
			fy = filb;
		end
		// accumulator subtract instructions
		SUBL: begin
			aop = SUB;
			x = a;
			y = im;
		end
		SUBX: begin
			faop = SUB;
			fx = a;
			fy = filb;
		end
		// compares
		CMPAL: begin
			aop = CMP;
			x = a;
			y = im;
		end
		CMPAX: begin
			faop = CMP;
			fx = a;
			fy = filb;
		end
		// conditional loads
		LDEAL: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		LDEAX: begin
			raop = RETY;
			rx = 8'd0;
			ry = filb;
		end
		// jumps
		RJMP: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		JMPB: begin
			raop = RETY;
			rx = 8'd0;
			ry = b;
		end
		// conditional jumps
		RJMPE: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		// shifts
		LSHFT: begin
			aop = LSHIFT;
			x = a;
			y = im;
		end
		// paging
		PPGE: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
		UPGE: begin
			raop = RETY;
			rx = 8'd0;
			ry = im;
		end
	endcase
end

endmodule
