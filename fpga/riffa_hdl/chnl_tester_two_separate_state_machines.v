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
	parameter C_PCI_DATA_WIDTH = 9'd32  // NUMBER_OF_BITS_PER_TRANSACTION
)
(
	/*Signals to receive from PC via RIFFA core, transmit to FPGA via this chnl_tester module*/
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
	
	/*Signals to transmit to PC via RIFFA core, receive from FPGA via this chnl_tester module*/
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

parameter NUMBER_OF_BITS_PER_WORD= 32;  // (4 byte words),  please refer to http://riffa.ucsd.edu/node/10

reg [C_PCI_DATA_WIDTH-1:0] rData={C_PCI_DATA_WIDTH{1'b0}};  // data received from PC
reg [C_PCI_DATA_WIDTH-1:0] tData;  // data to be sent to PC
reg [31:0] rLen=0;
reg [31:0] rCount=0;  // number of words received from PC
reg [31:0] tCount=0;	 // number of words received from FPGA
reg [1:0] rState=0;   // Receiver states
reg [1:0] tState=0;   // Transmitter states

assign CHNL_RX_CLK = CLK;
assign CHNL_RX_ACK = (rState == 2'd1);
assign CHNL_RX_DATA_REN = (rState == 2'd1); // !overlay_input_FIFO_is_full;

assign CHNL_TX_CLK = CLK;
assign CHNL_TX = (tState == 2'd1);
assign CHNL_TX_LAST = 1'd0;
assign CHNL_TX_LEN = tCount; // in words
assign CHNL_TX_OFF = 0;
assign CHNL_TX_DATA_VALID = (tState == 2'd1);
assign CHNL_TX_DATA = tData;

/*
wire overlay_input_FIFO_is_full;
wire overlay_output_FIFO_is_empty;


// fpga overlay instantiation for "https://github.com/louislxw/time-multiplexed-overlay/"
top_overlay overlay(.bus_clk(CLK), .user_w_write_32_open(RST), .user_w_write_32_data(CHNL_RX_DATA), .user_w_write_32_wren(CHNL_RX_DATA_VALID && CHNL_RX_DATA_REN), .user_w_write_32_full(overlay_input_FIFO_is_full), 
							.user_r_read_32_open(RST), .user_r_read_32_rden(CHNL_TX_DATA_VALID && CHNL_TX_DATA_REN && (!overlay_output_FIFO_is_empty)), .user_r_read_32_data(CHNL_TX_DATA), .user_r_read_32_empty(overlay_output_FIFO_is_empty));
*/

always @(posedge CLK) begin

	if (RST) begin
		rState <= #1 0;
		rLen <= #1 0;
		rCount <= #1 0;
	end
	
	else begin
		case (rState)
		
			2'd0: begin // Wait for start of RX, save length
				if (CHNL_RX) begin
					rLen <= #1 CHNL_RX_LEN;
					rCount <= #1 0;
					rState <= #1 2'd1;
				end
			end
			
			2'd1: begin // Wait for last data in RX, save value
				if (CHNL_RX_DATA_VALID) begin
					rData <= CHNL_RX_DATA;
					rCount <= #1 rCount + (C_PCI_DATA_WIDTH/NUMBER_OF_BITS_PER_WORD);  // NUMBER_OF_BITS_PER_TRANSACTION/NUMBER_OF_BITS_PER_WORD=NUMBER_OF_WORDS_PER_TRANSACTION
				end
				if (rCount >= rLen)
					rState <= #1 2'd0;
			end

			default: begin
				rLen <= #1 0;
				rCount <= #1 0;
				rState <= #1 2'd0;
			end
		
		endcase
	end
end

always @(posedge CLK) begin

	if (RST) begin
		tState <= #1 0;
		tCount <= #1 0;
	end
	
	else begin
		case (tState)

			2'd0: begin // Prepare for TX
				tCount <= #1 (C_PCI_DATA_WIDTH/NUMBER_OF_BITS_PER_WORD);
				tState <= #1 2'd1;
			end

			2'd1: begin // Start TX with save length and data value
				if (CHNL_TX_DATA_REN & CHNL_TX_DATA_VALID) begin
					tData <= #1 { rData[(C_PCI_DATA_WIDTH)-1:3*(C_PCI_DATA_WIDTH/4)],   rData[3*(C_PCI_DATA_WIDTH/4)-1:2*(C_PCI_DATA_WIDTH/4)], 
								  rData[2*(C_PCI_DATA_WIDTH/4)-1:(C_PCI_DATA_WIDTH/4)], rData[(C_PCI_DATA_WIDTH/4)-1:0]};
					tCount <= #1 tCount + (C_PCI_DATA_WIDTH/NUMBER_OF_BITS_PER_WORD);  // NUMBER_OF_BITS_PER_TRANSACTION/NUMBER_OF_BITS_PER_WORD=NUMBER_OF_WORDS_PER_TRANSACTION
				end
				if (tCount >= rLen)
					tState <= #1 2'd0;
			end

			default: begin
				tCount <= #1 0;
				tState <= #1 2'd0;
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
