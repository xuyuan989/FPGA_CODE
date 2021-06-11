`timescale 1ns / 1ps
 module uart_top(
  input				 clk,
  input				 rst_n, 
  input [7:0]		 uart_send_data,
  input		 		 uart_data_ready,			// begin to send data to ram
  output				 tx_usb,
  output				 uart_idle

);

//.....................send data.............................................
reg		[7:0] 	send_ble_data;
reg		[7:0] 	current_send_state;
reg      send_ble_log;
wire     USB_idle;
reg		change_log;
wire     clk_out;
wire		usb_over;
reg		uart_complet;
assign	uart_idle = uart_complet;
clk_div u1(
    .clk50(clk), 
    .rst_n(rst_n), 
    .clkout_16(clk_out),
	 .clkout_2(clk_2)
    );
//........RX_DATA_BLE---------->tx_usb
uart_tx TX_USB(
    .clk(clk_out), 
    .rst_n(rst_n), 
    .datain(send_ble_data), //RX_DATA_BLE, data in (PIN TO DATA)
    .wrsig(send_ble_log), //BLE_rdsig, begin to send
    .idle(USB_idle), //idle, not use
    .tx(tx_usb),
	 .send_state(usb_over)
    );

//..................UART函数........................
localparam USB_IDLE    = 0;
localparam USB_CLOCK   = 1;
localparam USB_OUT     = 2;
localparam USB_WAIT    = 3;
localparam USB_TIME    = 4;

reg[3:0]   usb_state;
reg 		  two_clock; 
reg uart_wait_before;

//Save SPI data to ram which used to uart

reg  [7:0]   uart_rdaddr, uart_wraddr;
reg 			 uart_rden;//uart_wren,
wire [7:0]   uart_out_data;
reg  [8:0]   uart_wrdata_count,uart_redata_count;//+1

RAM_2PORT uart_2data(
	 .rdaddress(uart_rdaddr),
	 .wraddress(uart_wraddr),
	 .clock(clk),
	 .rden(uart_rden),
	 .data(uart_send_data),
	 .wren(uart_data_ready),//uart_wren, significant
	 .q(uart_out_data)
);

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
    begin
			 usb_state <= USB_IDLE;
			 two_clock   <= 1;
			 send_ble_log  <= 0;
			 uart_wait_before <= 0;
			 uart_rdaddr <= 8'd0;
			 uart_wraddr <= 8'd0;
//			 uart_wren  <= 1'd0;
			 uart_rden  <= 1'd0;
			 uart_wrdata_count  <= 8'd0;
			 uart_redata_count  <= 8'd0;
			 uart_complet  <= 1'd1;
	 end
	 else case(usb_state)
			 USB_IDLE:begin
						if(uart_wrdata_count >= 'd10)begin//256
									 usb_state <= USB_WAIT;
									 uart_wrdata_count  <= 8'd0;
									 uart_wraddr <= 8'd0;
//									 uart_wren  <= 1'd0;
									 uart_complet  <= 1'd0;
						end
						else begin	//read spi data valid,(state == S_READ) && (data_valid == 'd1)  if(uart_data_ready)								  
									 uart_wrdata_count <= uart_wrdata_count + 1;
									 uart_wraddr <= uart_wraddr + 1;//next data	
									 usb_state <= USB_IDLE;
//									 uart_wren  <= 1'd1;
									 uart_complet  <= 1'd0;
						end	
//						else
//									 uart_complet  <= 1'd1;
			 end
			 USB_WAIT:begin//waite for
						uart_complet  <= 1'd0;
						if(second1)begin
									 usb_state <= USB_OUT; 
						end
						else
									 usb_state <= USB_WAIT;
			 end
			 USB_OUT:begin//read data	
						 uart_redata_count <= uart_redata_count + 1;
						 uart_rdaddr <= uart_rdaddr + 1; 
						 if(uart_redata_count < 'd10) begin//read the first data is invalid,-1, 
								 send_ble_data <= uart_out_data;
								 usb_state <= USB_CLOCK;
						 end
						 else if(uart_redata_count >= 'd10)begin//256, add 1,  
								 usb_state <= USB_TIME;
								 uart_redata_count  <= 8'd0;
								 uart_rdaddr <= 8'd0;
								 uart_rden  <= 1'd0;
						 end										
			 end
			 USB_CLOCK:begin//uart send clock
						if(two_clock)begin
							send_ble_log  <= 1;//..............1
							two_clock   <= 0;
						end
						else if(!two_clock && usb_over) begin
							send_ble_log  <= 0;//.............0
						end
						else if(!two_clock && !usb_over && !send_ble_log) begin
							two_clock  <= 1;
							usb_state <= USB_OUT;
						end
			end
			USB_TIME:begin
						if((uart_time == 2'd2))
							usb_state <= USB_IDLE;
						else
							usb_state <= USB_TIME;
			end
			default:usb_state <= USB_IDLE;
	 endcase
end

//..................WIRTE函数........................
reg[31:0] timer_run1, timer_uart1;
reg second1;
reg [1:0] uart_time;
always@(posedge clk or negedge rst_n )begin
    if(rst_n == 1'b0)
		begin
		  second1 <= 0;
		  timer_run1 <= 32'd0; 
		  timer_uart1 <= 32'd0; 
		  uart_time <= 2'd0;
		end 
	else
	begin
			timer_run1 <= timer_run1 + 32'd1;
			
			if(timer_run1 > 32'd999_999_99)//999_999为1秒
				begin
					 timer_run1 <= 32'd0;
					 second1 = ~ second1;
				end	
			//uart wait for a long time ,at USB_WATIME
			if((usb_state == USB_TIME) && (uart_time == 2'd0)) begin
					 uart_time <= 2'd1;
					 timer_uart1 <= 32'd0;
			end
			else if(uart_time == 2'd2)begin
						 uart_time <= 2'd0;
			end
			else if(uart_time == 2'd1)begin
					 timer_uart1 <= timer_uart1 + 32'd1;
					 if(timer_uart1 > 32'd4_999_999_99)begin
						 uart_time <= 2'd2;
					 end
			end

			
	end
end
endmodule 