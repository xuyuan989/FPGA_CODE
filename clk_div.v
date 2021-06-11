`timescale 1ns / 1ps
//
// Module Name:    clkdiv 
//
module clk_div
#(
	parameter CLK_FRE = 50,      //clock frequency(Mhz)
	parameter BAUD_RATE = 115200 //serial baud rate
)
(
	input clk50,              //系统时钟
	input rst_n,              //收入复位信号
	output reg clkout_16,            //采样时钟输出
	output reg clkout_2            //采样时钟输出
);

reg [15:0] cnt;
reg [31:0] nodiv_cnt;
localparam 	CYCLE = CLK_FRE * 1000000 / BAUD_RATE / 16;//16分频，提高检测精度

 
/*分频进程, 50Mhz的时钟326分频,9600*/
/*分频进程, 50Mhz的时钟27分频,115200*/
always @(posedge clk50 or negedge rst_n)   
begin
  if (!rst_n) begin
     clkout_16 <=1'b0;
	  cnt<=0;
  end	  
  else if(cnt == CYCLE / 2) begin//162,13
    clkout_16 <= 1'b1;
    cnt <= cnt + 16'd1;
  end 
  else if(cnt == CYCLE ) begin//325,27
    clkout_16 <= 1'b0;
    cnt <= 16'd0;
  end
  else begin
    cnt <= cnt + 16'd1;
  end
end
//不分频
always @(posedge clk50 or negedge rst_n)   
begin
  if (!rst_n) begin
     clkout_2 <=1'b0;
	  nodiv_cnt<=0;
  end	  
  else if(nodiv_cnt == CYCLE / 2 * 8) begin//162,13
    clkout_2 <= 1'b1;
    nodiv_cnt <= nodiv_cnt + 16'd1;
  end 
  else if(nodiv_cnt == CYCLE * 8 ) begin//325,27
    clkout_2 <= 1'b0;
    nodiv_cnt <= 16'd0;
  end
  else begin
    nodiv_cnt <= nodiv_cnt + 16'd1;
  end
end

endmodule