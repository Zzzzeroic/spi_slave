`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/07 21:32:18
// Design Name: 
// Module Name: top_spi_slave
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

`define SPI_ADDR_LEN 8
`define SPI_WORD_LEN 16
`define SPI_WAIT_LEN 2

module top_spi_slave
(
    input i_master_clock,
    input i_rst_n,
    //word to return to master
    input [`SPI_WORD_LEN-1:0] data_word_send,
    //spi ports
    input i_SCLK,
    input i_SS,
    input i_MOSI,
    output o_MISO,
    //output params
    output reg_operate,
    output spi_rw,
    output spi_write,
    output spi_read,
    output [`SPI_ADDR_LEN-1:0] spi_addr,
    output [`SPI_WORD_LEN-1:0] spi_data
    );

    spi_slave_module
    #(
        .SPI_WORD_LEN(`SPI_WORD_LEN),
        .SPI_WAIT_LEN(`SPI_WAIT_LEN),
        .SPI_ADDR_LEN(`SPI_ADDR_LEN)
    ) u_spi_slave
    (
        .master_clock(i_master_clock),
        .i_rst_n(i_rst_n),
        .SCLK_IN(i_SCLK),
        .SS_IN(i_SS),
        .MOSI(i_MOSI),
        .MISO(o_MISO),
        .data_word_send(data_word_send),
        .data_word_recv(),
        //user define wires
        .reg_operate(reg_operate),
        .spi_rw(spi_rw),							//0->write, 1->read
        .spi_write(spi_write),
        .spi_read(spi_read),
        .spi_addr(spi_addr),
        .spi_data(spi_data)
    );

endmodule
