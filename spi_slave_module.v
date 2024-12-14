`default_nettype wire
`timescale 1ns/1ps

`define SPI_MODULE_COMMAND_LEN 3

`define SPI_STATUS_IDLE 'b000
`define SPI_STATUS_CYCLE_BITS 'b111

`define CYCLE_STATUS_IDLE 	'b000
`define CYCLE_STATUS_ADDR 	'b010
`define CYCLE_STATUS_WAIT 	'b011
`define CYCLE_STATUS_READ 	'b100
`define CYCLE_STATUS_WRITE 	'b101

module spi_slave_module
	#( 
	parameter CPOL = 1'b0,						//Clock Polarity, decide the default voltage
	parameter CPHA = 1'b0,						//Clock Phase, 0-> sample at the first edge
	parameter INVERT_DATA_ORDER = 1'b0,
	parameter SPI_ADDR_LEN = 8,
	parameter SPI_WORD_LEN = 16,
	parameter SPI_WAIT_LEN = 2 
	)
	( 
	input wire master_clock,
	input wire i_rst_n,
	input wire SCLK_IN,
	input wire SS_IN,
	input wire MOSI,
	output reg MISO,
	input wire [SPI_WORD_LEN - 1:0] data_word_send,
	output wire [SPI_ADDR_LEN + SPI_WORD_LEN - 1:0] data_word_recv,
	//user define wires
	output reg reg_operate, 					//notify the register to operate
	output reg spi_rw,							//0->write, 1->read
	output reg spi_write,
	output reg spi_read,
	output reg [SPI_ADDR_LEN - 1:0] spi_addr,
	output reg [SPI_WORD_LEN - 1:0] spi_data
	);

	//Local registers and wires
	reg status_ignore_first_edge;
	
	wire rising_sclk_edge;
	wire falling_sclk_edge;
	wire rising_SS_edge;
	wire falling_SS_edge;
	
	reg [SPI_ADDR_LEN + SPI_WAIT_LEN + SPI_WORD_LEN:0] data_word_recv_reg;
	reg [4:0] bit_counter;
	
	reg [`SPI_MODULE_COMMAND_LEN - 1:0]spi_status;
	reg [`SPI_MODULE_COMMAND_LEN - 1:0]cyc_status;
	
	assign data_word_recv = data_word_recv_reg;
	
	//Edge detector modules
	pos_edge_det spi_edge_pos( .sig(SCLK_IN), .clk(master_clock), .pe(rising_sclk_edge));
	neg_edge_det spi_edge_neg( .sig(SCLK_IN), .clk(master_clock), .ne(falling_sclk_edge));
	pos_edge_det spi_ss_pos  ( .sig(SS_IN), .clk(master_clock), .pe(rising_SS_edge));
	neg_edge_det spi_ss_neg	 ( .sig(SS_IN), .clk(master_clock), .ne(falling_SS_edge));
	
	wire delay_pol =  (CPHA) ? ( (CPOL) ? (rising_sclk_edge) : (falling_sclk_edge)  ) : ( (CPOL) ? (SCLK_IN) : (!SCLK_IN) );	
	//sample edge
	wire get_number_edge = (CPHA) ? ( (CPOL) ? (rising_sclk_edge) : (falling_sclk_edge) ) : ( (CPOL) ? (falling_sclk_edge) : (rising_sclk_edge) );
	//write edge
	wire switch_number_edge = (CPHA) ? ( (CPOL) ? (falling_sclk_edge) : (rising_sclk_edge) ) : ( (CPOL) ? (rising_sclk_edge) : (falling_sclk_edge) );
	/*
	//SS sample 2 cycles
	reg[1:0] SS_reg;
	always @(posedge master_clock or negedge i_rst_n) begin
		if(~i_rst_n) begin
			SS_reg <= 2'b11;
		end
		else begin
			SS_reg <= {SS_reg[0],SS_IN};
		end
	end
	wire SS =  (SS_reg==2'b00)?1'b0:1'b1;
	*/
	
	//assign MISO = (activate_ss) ? data_word_send[bit_counter] : 1'b0;
	
	// todo : assign reg_addr = ()

	always @(posedge master_clock or negedge i_rst_n) begin
		if (~i_rst_n) begin
			//do reset stuff
			bit_counter <= (INVERT_DATA_ORDER) ? (0) : (SPI_ADDR_LEN + SPI_WORD_LEN + SPI_WAIT_LEN);
			status_ignore_first_edge <= 1'b0;
			spi_status <= `SPI_STATUS_IDLE;
			data_word_recv_reg <= 'b0;
		end
		else begin
			if(rising_SS_edge) begin//SS is pulled high, reset the state
				bit_counter <= (INVERT_DATA_ORDER) ? (0) : (SPI_ADDR_LEN + SPI_WORD_LEN + SPI_WAIT_LEN);
				spi_status <= `SPI_STATUS_IDLE;
			end		
			else begin
			case(spi_status)
				`SPI_STATUS_IDLE: begin
					if(falling_SS_edge) begin //falling edge, start the process
						status_ignore_first_edge <= 1'b0;
						spi_status <= `SPI_STATUS_CYCLE_BITS;	
					end
				end
				`SPI_STATUS_CYCLE_BITS: begin
					//sample edge
					if(get_number_edge) data_word_recv_reg[bit_counter] <= MOSI;
					//write edge
					if(switch_number_edge) begin
						//make sure when CPHA->1, this module can write at the begining of the process
						if(CPHA && !status_ignore_first_edge) status_ignore_first_edge <= 1'b1;
						else begin
							if(bit_counter ==  ((INVERT_DATA_ORDER) ? (SPI_ADDR_LEN + SPI_WORD_LEN + SPI_WAIT_LEN) : ('sd0)) ) begin 
								//Word normally processed, reset
								bit_counter <= (INVERT_DATA_ORDER) ? (0) : (SPI_ADDR_LEN + SPI_WORD_LEN + SPI_WAIT_LEN);
								spi_status <= `SPI_STATUS_IDLE;
							end
							else bit_counter <= (INVERT_DATA_ORDER) ? (bit_counter + 1) : (bit_counter - 1);	
						end
					end
				end
				default:begin
					spi_status <= `SPI_STATUS_IDLE;
					bit_counter <= (INVERT_DATA_ORDER) ? (0) : (SPI_ADDR_LEN + SPI_WORD_LEN + SPI_WAIT_LEN);
					data_word_recv_reg <= 'b0;
				end
			endcase
			end
		end
	end

	//MISO output logic
	always @(posedge master_clock or negedge i_rst_n) begin
		if(~i_rst_n) begin
			MISO 	 	 <= 'b0;
			spi_rw		 <= 'b0;
			spi_addr     <= 'd0;
			spi_data     <= 'd0;
		end
		else begin
			if(switch_number_edge) begin
				case (cyc_status)
				`CYCLE_STATUS_IDLE: begin
					MISO   		<= 'b0;
					spi_rw 		<= data_word_recv_reg[SPI_ADDR_LEN + SPI_WAIT_LEN + SPI_WORD_LEN];
				end
				`CYCLE_STATUS_ADDR: begin
					MISO 		<= 'b0;
					spi_addr    <= data_word_recv_reg[SPI_WORD_LEN + SPI_WAIT_LEN + SPI_ADDR_LEN-1 : 
																SPI_WORD_LEN + SPI_WAIT_LEN];
				end
				`CYCLE_STATUS_WAIT: begin
					MISO 		<= (bit_counter==SPI_WORD_LEN && spi_rw)?data_word_send[SPI_WORD_LEN-1]:'b0;
				end
				`CYCLE_STATUS_READ: begin 	//send out reg info
					MISO 		<= (bit_counter>0)?data_word_send[bit_counter-1'b1]:1'b0;
				end
				`CYCLE_STATUS_WRITE: begin	//write info to reg
					MISO 		<= 'b0;
					spi_data	<= data_word_recv_reg[SPI_WORD_LEN-1:0];
				end
				default: begin
					MISO 	 	 <= 'b0;
					spi_rw		 <= 'b0;
					spi_addr     <= 'd0;
					spi_data     <= 'd0;
				end
				endcase
			end
		end
	end

	always @(posedge master_clock or negedge i_rst_n) begin
		if (~i_rst_n) begin
			//do reset stuff
			cyc_status 	<= `CYCLE_STATUS_IDLE;
			reg_operate <= 1'b0;
			spi_write  	<= 1'b0;
			spi_read	<= 1'b0;
		end
		else begin
			if (rising_SS_edge) begin //transfer error, SS is pulled high in advance. reset
				cyc_status <= `CYCLE_STATUS_IDLE;
				reg_operate <= 1'b0;
				spi_write  	<= 1'b0;
				spi_read	<= 1'b0;
			end
			else begin
				case (cyc_status)
				`CYCLE_STATUS_IDLE: begin	//rw bit
					reg_operate <= 1'b0;
					spi_write  	<= 1'b0;
					spi_read	<= 1'b0;
					if(bit_counter == ((INVERT_DATA_ORDER) ? ('sd0) : (SPI_ADDR_LEN + SPI_WORD_LEN + SPI_WAIT_LEN))) begin
						if(switch_number_edge) begin
							cyc_status <= `CYCLE_STATUS_ADDR;
						end
					end
				end

				`CYCLE_STATUS_ADDR:begin	
					if(bit_counter == ((INVERT_DATA_ORDER) ? (SPI_ADDR_LEN) : (SPI_WORD_LEN + SPI_WAIT_LEN))) begin
						if(switch_number_edge) begin
							cyc_status <= `CYCLE_STATUS_WAIT;
							if(spi_rw) begin//read mode, inform reg to read value
								reg_operate <= 1'b1;
								spi_read 	<= 1'b1;
							end
						end
					end
				end

				`CYCLE_STATUS_WAIT:begin
					reg_operate <= 1'b0;
					spi_read 	<= 1'b0;
					if(bit_counter == ((INVERT_DATA_ORDER) ? (SPI_ADDR_LEN + SPI_WAIT_LEN) : (SPI_WORD_LEN))) begin
						if(switch_number_edge) begin
							cyc_status <= (spi_rw)?`CYCLE_STATUS_READ:`CYCLE_STATUS_WRITE;
						end
					end
				end

				`CYCLE_STATUS_READ:begin
					reg_operate <= 1'b0;
					if(bit_counter == ((INVERT_DATA_ORDER) ? (SPI_ADDR_LEN + SPI_WAIT_LEN + SPI_WORD_LEN) : (0)))
						if(switch_number_edge) begin
							cyc_status <= `CYCLE_STATUS_IDLE;
						end
				end

				`CYCLE_STATUS_WRITE:begin
					if(bit_counter == ((INVERT_DATA_ORDER) ? (SPI_ADDR_LEN + SPI_WAIT_LEN + SPI_WORD_LEN) : (0))) begin
						if(switch_number_edge) begin
							cyc_status <= `CYCLE_STATUS_IDLE;
							reg_operate<= 1'b1;
							spi_write  <= 1'b1;
						end
					end
				end
				endcase
			end
		end
	end
endmodule