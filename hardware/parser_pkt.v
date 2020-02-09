/*
 *  iCore_hardware -- Hardware for TuMan RISC-V (RV32I) Processor Core.
 *
 *  Copyright (C) 2019-2020 Junnan Li <lijunnan@nudt.edu.cn>.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *	Data: 2020.01.01
 *	Description: This module is used to parsing packet, and only pass TCP packet.
 */

module parser(
	input				clk,
	input				rst_n,
    // FAST packets from CPU (ARM A8) or Physical ports, the format is according to fast 
	//	 project (www.http://www.fastswitch.org/)
	input				data_in_valid,
	input		[133:0]	data_in,	// 2'b01 is head, 2'b00 is body, and 2'b10 is tail;
	
	output	reg			data_out_valid,
	output	reg	[133:0]	data_out
);

	/*	reg and wire */
	reg					dataValid_temp[2:0];
	reg			[133:0]	data_temp[2:0];

	integer i;
	/*	parse packet */
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			// reset
			data_out_valid		<= 1'b0;
			data_out			<= 134'b0;
			for(i=0; i<3; i=i+1) begin
				dataValid_temp[i]<= 1'b0;
				data_temp[i]	<= 134'b0;
			end
		end
		else begin
			dataValid_temp[0]	<= data_in_valid;
			data_temp[0]		<= data_in;
			for(i=1; i<3; i=i+1) begin
				dataValid_temp[i]<= dataValid_temp[i-1];
				data_temp[i]	<= data_temp[i-1];
			end
					
			/**	whoes mac address is 48'hffff_ffff_ffff or 48'h8c:16:45:49:25:01 
			 ** head_2:	data_in;
			 **	head_1: temp[0];
			 **	meta_1:	temp[1];
			 **	meta_0: temp[2];
			 **/
			if(dataValid_temp[2] == 1'b1 && data_temp[2][133:132] == 2'b01 && 
				(data_temp[0][127:80] == 48'hffff_ffff_ffff || data_temp[0][127:80] == 48'h8c16_4549_2501)) begin
					data_out		<= {data_temp[2][133:128],16'b0,data_temp[2][111:32],32'd1};	// cpu is not ready;
					data_out_valid	<= 1'b1;
			end
			else if(dataValid_temp[2] == 1'b0) begin
				data_out_valid	<= 1'b0;
			end
			else begin
				data_out		<= data_temp[2];
				data_out_valid	<= data_out_valid;
			end 
		end
	end




	

	
endmodule    
