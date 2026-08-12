`timescale 1ns / 1ps

module router_tb;

    reg clk;
    reg resetn;
    reg packet_valid;
    reg [7:0] data_in;
    reg read_enb_0, read_enb_1, read_enb_2;
    
 
    wire [7:0] data_out_0, data_out_1, data_out_2;
    wire vld_out_0, vld_out_1, vld_out_2;
    wire err;
    wire busy;

    integer i;
    reg [7:0] calc_parity;

    router_top DUT (
        .clk(clk),
        .resetn(resetn),
        .packet_valid(packet_valid),
        .data_in(data_in),
        .read_enb_0(read_enb_0),
        .read_enb_1(read_enb_1),
        .read_enb_2(read_enb_2),
        .data_out_0(data_out_0),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2),
        .vld_out_0(vld_out_0),
        .vld_out_1(vld_out_1),
        .vld_out_2(vld_out_2),
        .err(err),
        .busy(busy));

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    initial begin
        resetn = 1'b1;
        packet_valid = 1'b0;
        data_in = 8'h00;
        read_enb_0 = 1'b0;
        read_enb_1 = 1'b0;
        read_enb_2 = 1'b0;
        calc_parity = 8'h00;

        $display("%0t  Reset...", $time);
        @(negedge clk);
        resetn = 1'b0; 
        @(negedge clk);
        resetn = 1'b1; 
        $display("%0t  Reset Complete.", $time);
        
        #20;

 
      $display("%0t STARTING PACKET  ", $time);
        
        wait(~busy);
        @(negedge clk);
        
        data_in = {6'd4, 2'b00}; 
        calc_parity = data_in;       
        packet_valid = 1'b1;         
        $display("%0t Header Sent: %b", $time, data_in);
        @(negedge clk);
        

        for (i = 0; i < 4; i = i + 1) begin
            wait(~busy); 
            
          data_in = $random % 64; 
            calc_parity = calc_parity ^ data_in; 
          $display("%0t Payload Byte %0d Sent: %h", $time, i+1, data_in);
            
         
            if (i == 3) begin
                packet_valid = 1'b0;
            end
            
            @(negedge clk);
        end
        
       
        wait(~busy);
        data_in = calc_parity;
        $display("%0t Parity Byte Sent: %h", $time, data_in);
        @(negedge clk);
        
        $display("%0t Packet  Transmission Complete.", $time);

        #40;
        if (vld_out_0) begin
            $display("%0t Receiver 0 detected valid data. Starting read...", $time);
            read_enb_0 = 1'b1;
          $monitor("data out = %h",data_out_0);
            #70; 
            read_enb_0 = 1'b0;
        end
      
		$finish;
    end

       
endmodule