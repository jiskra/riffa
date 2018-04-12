// ----------------------------------------------------------------------
// Copyright (c) 2016, The Regents of the University of California All
// rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
// 
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
// 
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
// 
//     * Neither the name of The Regents of the University of California
//       nor the names of its contributors may be used to endorse or
//       promote products derived from this software without specific
//       prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL REGENTS OF THE
// UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
// OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
// TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
// DAMAGE.
// ----------------------------------------------------------------------
//----------------------------------------------------------------------------
// Filename:			chnl_tester.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Sample RIFFA channel user module. Designed to exercise
// 						the RIFFA TX and RX interfaces. Receives data on the
//						RX interface and saves the last value received. Sends
//						the same amount of data back on the TX interface. The
//						returned data starts with the last value received, 
//						resets and increments to end with a value equal to the
//						number of (4 byte) words sent back on the TX interface.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
`timescale 1ns/1ns
module chnl_tester #(
	parameter C_PCI_DATA_WIDTH = 9'd32
)
(
	input CLK,
	input RST,
	output CHNL_RX_CLK, 
	input CHNL_RX, 
	output CHNL_RX_ACK, 
	input CHNL_RX_LAST, 
	input [31:0] CHNL_RX_LEN, 
	input [30:0] CHNL_RX_OFF, 
	input [C_PCI_DATA_WIDTH-1:0] CHNL_RX_DATA, 
	input CHNL_RX_DATA_VALID, 
	output CHNL_RX_DATA_REN,
	
	output CHNL_TX_CLK, 
	output CHNL_TX, 
	input CHNL_TX_ACK, 
	output CHNL_TX_LAST, 
	output [31:0] CHNL_TX_LEN, 
	output [30:0] CHNL_TX_OFF, 
	output [C_PCI_DATA_WIDTH-1:0] CHNL_TX_DATA, 
	output CHNL_TX_DATA_VALID, 
	input CHNL_TX_DATA_REN
);

localparam NUMBER_OF_BITS_PER_WORD= 32; // (4 byte words),  please refer to http://riffa.ucsd.edu/node/10
localparam RCOUNT_BITWIDTH = 16;

localparam WAIT_FOR_RX = 3'd0;
localparam RX_IN_PROCESS = 3'd1;
localparam FIRST_ADD = 3'd2;
localparam FIRST_MULT = 3'd3;
localparam ADD_REG_1 = 3'd4;
localparam ADD_REG_2 = 3'd5;
localparam SHIFT_AND_SUBTRACT = 3'd6;

reg [C_PCI_DATA_WIDTH-1:0] rData={C_PCI_DATA_WIDTH{1'b0}};
reg [RCOUNT_BITWIDTH-1:0] rLen=0;
reg [RCOUNT_BITWIDTH-1:0] rCount=0;
reg [2:0] rState=0;

reg[RCOUNT_BITWIDTH+1:0] rCount_plus_four;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_three;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_two;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_one;

// for register retiming purpose
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_four_reg1;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_three_reg1;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_two_reg1;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_one_reg1;

// for register retiming purpose
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_four_reg2;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_three_reg2;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_two_reg2;
reg[RCOUNT_BITWIDTH+1:0] rCount_plus_one_reg2;

assign CHNL_RX_CLK = CLK;
assign CHNL_RX_ACK = (rState == RX_IN_PROCESS);
assign CHNL_RX_DATA_REN = (rState == RX_IN_PROCESS);

assign CHNL_TX_CLK = CLK;
assign CHNL_TX = (rState == SHIFT_AND_SUBTRACT);  // assuming that SHIFT_AND_SUBTRACT is the last computation 
assign CHNL_TX_LAST = 1'd1;
assign CHNL_TX_LEN = rLen; // in words
assign CHNL_TX_OFF = 0;
assign CHNL_TX_DATA = rData;
assign CHNL_TX_DATA_VALID = (rState == SHIFT_AND_SUBTRACT);   // assuming that SHIFT_AND_SUBTRACT is the last computation 


always @(posedge CLK or posedge RST) begin
	if (RST) begin
		rLen <= #1 0;
		rCount <= #1 0;
		rState <= #1 0;
		rData <= #1 0;
	end
	else begin
		case (rState)
		
		WAIT_FOR_RX: begin // Wait for start of RX, save length
			if (CHNL_RX) begin
				rLen <= #1 CHNL_RX_LEN;
				rCount <= #1 0;
				rState <= #1 RX_IN_PROCESS;
			end
		end
		
		RX_IN_PROCESS: begin // Wait for last data in RX, save value
			if (CHNL_RX_DATA_VALID) begin
				rData <= #1 CHNL_RX_DATA;
				rCount <= #1 rCount + (C_PCI_DATA_WIDTH/NUMBER_OF_BITS_PER_WORD);   // NUMBER_OF_BITS_PER_TRANSACTION/NUMBER_OF_BITS_PER_WORD=NUMBER_OF_WORDS_PER_TRANSACTION
			end
			if (rCount >= rLen) begin
				rCount <= #1 (C_PCI_DATA_WIDTH/NUMBER_OF_BITS_PER_WORD);  // prepare counter for addition
				rState <= #1 FIRST_ADD;  // after finish receiving data, perform multiple stages of computations
			end
		end

		FIRST_ADD: begin // Start with first addition

				//rData <= #1 {rCount + 4, rCount + 3, rCount + 2, rCount + 1};
				//(rData*(rData*(16*rData*rData-20)*rData+5));
				
				// implements x+k for four different pieces of 32-bit data
				rCount_plus_four<= rCount + 4;
				rCount_plus_three<= rCount + 3;
				rCount_plus_two<= rCount + 2;
				rCount_plus_one<= rCount + 1;
				
				rState <= #1 ADD_REG_1;

		end
		
		ADD_REG_1: begin
				rCount_plus_four_reg1 <= rCount_plus_four;
				rCount_plus_three_reg1 <= rCount_plus_three;
				rCount_plus_two_reg1 <= rCount_plus_two;
				rCount_plus_one_reg1 <= rCount_plus_one;
				
				rState <= #1 ADD_REG_2;
		end

		ADD_REG_2: begin
				rCount_plus_four_reg2 <= rCount_plus_four_reg1;
				rCount_plus_three_reg2 <= rCount_plus_three_reg1;
				rCount_plus_two_reg2 <= rCount_plus_two_reg1;
				rCount_plus_one_reg2 <= rCount_plus_one_reg1;
				
				rState <= #1 FIRST_MULT;
		end
		
		FIRST_MULT: begin // Start with first multiplication

				//rData <= #1 {rCount + 4, rCount + 3, rCount + 2, rCount + 1};
				//(rData*(rData*(16*rData*rData-20)*rData+5));
				rData <= #1 {((rCount_plus_four_reg2)*(rCount_plus_four_reg2)), ((rCount_plus_three_reg2)*(rCount_plus_three_reg2)), 
								 ((rCount_plus_two_reg2)*(rCount_plus_two_reg2)), ((rCount_plus_one_reg2)*(rCount_plus_one_reg2))};    // implements x*x for four different pieces of 32-bit data

				rCount <= #1 (C_PCI_DATA_WIDTH/NUMBER_OF_BITS_PER_WORD);  // Prepare counter for Tx
				rState <= #1 SHIFT_AND_SUBTRACT;

		end
		
		SHIFT_AND_SUBTRACT: begin // Continue with shift and subtraction
			if (CHNL_TX_DATA_REN & CHNL_TX_DATA_VALID) begin  // then transmit the final computation result back to PC
				//rData <= #1 {rCount + 4, rCount + 3, rCount + 2, rCount + 1};
				//(rData*(rData*(16*rData*rData-20)*rData+5));
				rData <= #1 (rData << 4) - 'h0014001400140014;    // implements 16*x*x-20 for four different pieces of 32-bit data
				
				rCount <= #1 rCount + (C_PCI_DATA_WIDTH/NUMBER_OF_BITS_PER_WORD);
				
				if (rCount >= rLen)
					rState <= #1 WAIT_FOR_RX;
			end
		end	
	
		default : begin
			rState <= WAIT_FOR_RX;
		end
		
		endcase
	end
end

/*
wire [35:0] wControl0;
chipscope_icon_1 cs_icon(
	.CONTROL0(wControl0)
);

chipscope_ila_t8_512 a0(
	.CLK(CLK), 
	.CONTROL(wControl0), 
	.TRIG0({3'd0, (rCount >= 800), CHNL_RX, CHNL_RX_DATA_VALID, rState}),
	.DATA({442'd0,
			CHNL_TX_DATA_REN, // 1
			CHNL_TX_ACK, // 1
			CHNL_RX_DATA, // 64
			CHNL_RX_DATA_VALID, // 1
			CHNL_RX, // 1
			rState}) // 2
);
*/

endmodule
