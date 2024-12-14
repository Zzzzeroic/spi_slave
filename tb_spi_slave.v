`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/08 13:41:12
// Design Name: 
// Module Name: tb_spi_slave
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

`define TEST_CYCLES_NUM 10000

`define SPI_ADDR_LEN 8
`define SPI_WORD_LEN 16
`define SPI_WAIT_LEN 2

`define TEST_ADDR 'h1F
`define TEST_WORD 'hFFF3

`define TEST_BYTE 'hFF_ABCD

module tb_spi_slave(
    );

	integer test_cycles = 0;
	reg chip_clock;
	
	wire SIGNAL_CLOCK;
	wire SIGNAL_SS;
	wire SIGNAL_DATA_S_MASTER;
	wire SIGNAL_DATA_S_SLAVE;
	wire reg_operate;
	
	reg [`SPI_WORD_LEN-1:0] reg_data_ret;
	reg reset_spi;
	wire spi_ready;
	
	reg reset_spi2;

	wire proc_word;
	reg [3:0] process_next_word;//inform master to send message
	
	wire [`SPI_WORD_LEN + `SPI_WAIT_LEN + `SPI_ADDR_LEN:0] recv_tmp_master;
	
    wire spi_rw;
    wire[`SPI_ADDR_LEN-1:0] spi_addr;
    wire[`SPI_WORD_LEN-1:0] spi_data;

    reg [`SPI_ADDR_LEN+`SPI_WAIT_LEN+`SPI_WORD_LEN:0] master_send_command;
    
	//Clock divider module
	spi_module 
	#( 
        .SPI_MASTER (1'b1),
        .SPI_WORD_LEN(`SPI_ADDR_LEN+`SPI_WAIT_LEN+`SPI_WORD_LEN+1'b1),
		.SCLK_DIV('d8)
    )
	spi_master
	( .master_clock(chip_clock),
	.SCLK_OUT(SIGNAL_CLOCK),
  	.SS_OUT(SIGNAL_SS),
  	.SS_IN(),
	.OUTPUT_SIGNAL(SIGNAL_DATA_S_MASTER),
	.processing_word(proc_word), 
	.process_next_word(process_next_word[3]),
	.data_word_send(master_send_command), 
	.INPUT_SIGNAL(SIGNAL_DATA_S_SLAVE),
	.data_word_recv(recv_tmp_master),
	.i_rst_n(reset_spi),
	.is_ready(spi_ready) 
	);
	
	top_spi_slave
	spi_slave
	( 
    .i_master_clock(chip_clock),
	.i_rst_n(reset_spi2),
	.data_word_send(reg_data_ret),
  	.i_SCLK(SIGNAL_CLOCK),
  	.i_SS(SIGNAL_SS),
	.i_MOSI(SIGNAL_DATA_S_MASTER),
	.o_MISO(SIGNAL_DATA_S_SLAVE),
	.reg_operate(reg_operate),
    .spi_rw(spi_rw),
	.spi_write(spi_write),
	.spi_read(spi_read),
    .spi_addr(spi_addr),
    .spi_data(spi_data)
    );

	initial begin
		//$dumpfile("test_data/output.vcd");
		//$dumpvars();	
		test_cycles <= 0;	
		process_next_word <= 4'b0;
		reset_spi <= 1'b0;
		reset_spi2<= 1'b0;
		reg_data_ret <= `TEST_WORD;
		//data <= 'sd0;
		//data <= `TEST_BYTE;
		chip_clock = 1'b0; //blocking
        master_send_command = 'b0;
	end

	reg [15:0] 	master_spi_word = 0;
	reg [7:0] 	master_spi_addr = 8'h84;
    reg [3:0] 	master_send_cnt = 0;
	always begin
		if(spi_ready) begin
			reset_spi <= 1'b1;
			reset_spi2<= 1'b1;
			if(!proc_word) begin
				if(!(process_next_word[3])) begin
					if(master_send_cnt <= 1) begin
						master_send_command <= {1'b0, master_spi_addr, 2'b00, master_spi_word};//write ABCD to reg FF
					end 
					else if(master_send_cnt <= 3) begin
						master_send_command <= {1'b1, master_spi_addr, 2'b00, master_spi_word};//read info from reg FF
					end
					else begin
						master_send_command <= {1'b1, master_spi_addr, 2'b00, master_spi_word};//read info from reg FF
					end
				end
				process_next_word <= process_next_word + 1'b1;
			end
			else if (proc_word && process_next_word[3])  begin
				process_next_word <= 4'b0;
				master_send_cnt <= master_send_cnt + 1;
				master_spi_addr <= master_spi_addr - 1'b1;
				master_spi_word <= master_spi_word + 1'b1;
				reg_data_ret <= reg_data_ret+1'b1;
			end
		end
		chip_clock <= ~chip_clock;
		test_cycles <= test_cycles + 1;
		if (test_cycles >= `TEST_CYCLES_NUM - 1) $finish;		
		#31.25; //16 MHz
    end
endmodule
