`default_nettype wire
`timescale 1ns/1ps

`define SPI_MODULE_COMMAND_LEN 3

`define SPI_STATUS_IDLE 'b000
`define SPI_STATUS_CYCLE_BITS 'b111

module spi_module
	#( parameter CPOL = 1'b0,					//Clock Polarity, decide the default voltage
	parameter CPHA = 1'b0,						//Clock Phase, 0-> sample at the first edge
	parameter SCLK_DIV = 'd4,
	parameter INVERT_DATA_ORDER = 1'b0,
	parameter SPI_MASTER = 1'b1,
	parameter SPI_WORD_LEN = 16 )

	( 
	input wire master_clock,
	output wire SCLK_OUT,
	output wire SS_OUT,
	input wire SS_IN,
	output wire OUTPUT_SIGNAL,
	output wire processing_word,
	input wire process_next_word,
	input wire [SPI_WORD_LEN - 1:0] data_word_send,
	input wire INPUT_SIGNAL,
	output wire [SPI_WORD_LEN - 1:0] data_word_recv,
	input wire i_rst_n,
	output wire is_ready );

	//Local registers and wires
	reg is_ready_reg;
	reg activate_ss;
	reg [1:0] activate_ss_shift_reg;
	reg activate_sclk;
	
	reg status_ignore_first_edge;
	
	wire rising_sclk_edge;
	wire falling_sclk_edge;
	
	reg [SPI_WORD_LEN - 1:0] data_word_recv_reg;
	
	reg [SPI_WORD_LEN - 1:1] bit_counter;
	
	reg [`SPI_MODULE_COMMAND_LEN - 1:0]spi_status;

	assign is_ready = is_ready_reg;
	
	assign data_word_recv = data_word_recv_reg;
	
	assign processing_word = (spi_status == `SPI_STATUS_IDLE && SS_OUT) ? 1'b0 : 1'b1;
	
	reg [4:0] sclk_cnt;
	wire SS = (SPI_MASTER) ? SS_OUT : SS_IN;
	generate 
	
		if(SPI_MASTER) begin
		
			assign SCLK_OUT = (activate_sclk) ? (sclk_cnt>=(SCLK_DIV>>1) ? 1'b1:1'b0) : (CPOL);
			assign SS_OUT = (activate_ss) ? 1'b0 : 1'b1;

		end
		
		always @(posedge master_clock or negedge i_rst_n) begin
			if(~i_rst_n) begin
				sclk_cnt <= 'd0;
			end
			else begin
				if(spi_status == `SPI_STATUS_CYCLE_BITS && activate_sclk) begin
					sclk_cnt <= (sclk_cnt<SCLK_DIV-1)?sclk_cnt + 1'b1:'d0;
				end
				else begin
					sclk_cnt <= 'd0;
				end
			end
		end
	endgenerate
	
	//Edge detector modules
	pos_edge_det spi_edge_pos( .sig(SCLK_OUT), .clk(master_clock), .pe(rising_sclk_edge));
	neg_edge_det spi_edge_neg( .sig(SCLK_OUT), .clk(master_clock), .ne(falling_sclk_edge));
	
	//sample edge
	wire get_number_edge = (CPHA) ? ( (CPOL) ? (rising_sclk_edge) : (falling_sclk_edge) ) : ( (CPOL) ? (falling_sclk_edge) : (rising_sclk_edge) );
	//write edge
	wire switch_number_edge = (CPHA) ? ( (CPOL) ? (falling_sclk_edge) : (rising_sclk_edge) ) : ( (CPOL) ? (rising_sclk_edge) : (falling_sclk_edge) );
	
	assign OUTPUT_SIGNAL = (activate_ss && spi_status == `SPI_STATUS_CYCLE_BITS) ? data_word_send[bit_counter] : 1'b0;

	always @(posedge master_clock or negedge i_rst_n) begin
	
		if (~i_rst_n) begin
			//do reset stuff
			activate_ss_shift_reg <= 2'b00;
			activate_sclk <= 1'b0;
			bit_counter <= (INVERT_DATA_ORDER) ? (0) : (SPI_WORD_LEN - 1);
			status_ignore_first_edge <= 1'b0;
			spi_status <= `SPI_STATUS_IDLE;
			data_word_recv_reg <= 'b0;
			is_ready_reg <= 1'b1;
		end
		else begin		
			case(spi_status)
				`SPI_STATUS_IDLE: begin
					//end, disable SS
					if(activate_ss_shift_reg=='d0) activate_ss <= 1'b0;
					else activate_ss_shift_reg <= activate_ss_shift_reg -1'b1;

					if(process_next_word) begin
						activate_ss_shift_reg <= 'd3;
						status_ignore_first_edge <= 1'b0;
						activate_ss <= 1'b1;	 				//enable SS
						spi_status <= `SPI_STATUS_CYCLE_BITS;	
					end
				end
				`SPI_STATUS_CYCLE_BITS: begin
					//begin, enable SCLK
					if(activate_ss_shift_reg == 'd0) activate_sclk <= 1'b1;
					else activate_ss_shift_reg <= activate_ss_shift_reg -1'b1;

					if(!SS) begin
						//sample edge
						if(get_number_edge) data_word_recv_reg[bit_counter] <= INPUT_SIGNAL;
						//write edge
						if(switch_number_edge) begin
							//make sure when CPHA->1, this module can write at the begining of the process
							if(CPHA && !status_ignore_first_edge) status_ignore_first_edge <= 1'b1;
							else begin
								if(bit_counter ==  ((INVERT_DATA_ORDER) ? (SPI_WORD_LEN -1) : ('sd0)) ) begin 
									//Word processed, reset
									activate_ss_shift_reg <= 'd3;
									activate_sclk <= 1'b0;
									bit_counter <= (INVERT_DATA_ORDER) ? (0) : (SPI_WORD_LEN - 1);
									spi_status <= `SPI_STATUS_IDLE;
								end
								else bit_counter <= (INVERT_DATA_ORDER) ? (bit_counter + 1) : (bit_counter - 1);		
							end
						end
					end
				end		
			endcase
		end
	end
endmodule
	
