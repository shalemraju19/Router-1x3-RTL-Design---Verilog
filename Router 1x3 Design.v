//fifo
module fifos (input clk,rst,we,re,input [7:0]din,output full,empty,output reg [7:0]dout);
  reg [3:0]wp,rp;
  reg [4:0]fifc;
  reg [7:0] mem [15:0];
  assign full = (fifc == 5'd16);
  assign empty = (fifc == 5'd0);
  always @(posedge clk ) begin
    if (!rst) begin
        wp<=0;
        rp<=0;
        dout<=0;
      fifc<=0;
    end
    else begin 
      if (we && re) 
        fifc<=fifc;
      else if  (we == 1 && full == 0 )
        fifc<=fifc+1;
      else if (re == 1 && empty  == 0) 
        fifc<=fifc-1;
      
    if (we == 1 && full == 0 ) begin 
        mem [wp]<=din;
        wp<=wp+1;
      end
    if (re == 1 && empty  == 0)  begin
      dout <= mem [rp];
      rp<=rp+1;
    end 
  end
  end
endmodule

//syn
module fifosyn (input clk,rst,detect_add,full_0,full_1,full_2,empty_0,empty_1,empty_2,write_enb_reg,
input [1:0]data,
output reg fifo_empty,fifo_full,
output vld_out_0,vld_out_1,vld_out_2 ,
output reg [2:0] write_enb);

       reg [1:0] add;
       always @(posedge clk) begin 
         if (!rst) 
           add<=2'b00;
           else if (detect_add) 
             add<= data;
       end
       always @(*) begin 
         case (add) 
           2'b00: begin 
             fifo_empty = empty_0;
             fifo_full=full_0;
           end
           2'b01: begin 
             fifo_empty = empty_1;
             fifo_full=full_1;
           end
           2'b10: begin 
             fifo_empty = empty_2;
             fifo_full=full_2;
           end
           default : begin
            
             fifo_empty = 0;
             fifo_full=1;
           end
         endcase
       end
       always @(*) begin 
         if (write_enb_reg) begin
           case (add)
          2'b00: write_enb = 3'b001; 
          2'b01: write_enb = 3'b010; 
          2'b10: write_enb = 3'b100;
           default: write_enb = 3'b000;
         endcase
       end
         else begin
             write_enb = 3'b000; 
         end
       end
       assign vld_out_0 = ~empty_0;
    assign vld_out_1 = ~empty_1;
    assign vld_out_2 = ~empty_2;
endmodule

//Reg Blk & Parity

module router_reg (
    input clk,
    input resetn,
    input packet_valid,
    input [7:0] data_in,
    input fifo_full,
    input detect_add,
    input ld_state,
    input lfd_state,
    input lp_state,
    input laf_state,
    input reset_int_reg,
    
    output reg [7:0] dout,
    output reg err,
    output reg parity_done,
    output reg low_packet_valid);

    reg [7:0] hold_header;
    reg [7:0] full_state_byte;
    reg [7:0] calc_parity;
    reg [7:0] packet_parity;
    always @(posedge clk) begin 
        if (!resetn) begin 
            hold_header     <= 8'b0;
            full_state_byte <= 8'b0;
            dout            <= 8'b0;
        end
        else begin 
            if (detect_add && packet_valid)
                hold_header <= data_in;
                
            if (ld_state && fifo_full) begin
                full_state_byte <= data_in;
            end
            if (lfd_state) begin
                dout <= hold_header;
            end
            else if (ld_state && !fifo_full) begin
                dout <= data_in;
            end
            else if (laf_state) begin
                dout <= full_state_byte;
            end
            else if (lp_state && !fifo_full) begin
                dout <= data_in;
            end
        end
    end
    always @(posedge clk) begin 
        if (!resetn) begin 
            err              <= 1'b0;
            calc_parity      <= 8'b0;
            packet_parity    <= 8'h00;
            parity_done      <= 1'b0;
            low_packet_valid <= 1'b0;
        end
        else begin 
            if (reset_int_reg) begin
                parity_done      <= 1'b0;
                low_packet_valid <= 1'b0;
            end
            else begin 
                if (ld_state && !packet_valid) begin
                    low_packet_valid <= 1'b1;
                end
                if (ld_state && !fifo_full && !packet_valid) begin
                    parity_done <= 1'b1;
                end
                else if (laf_state && low_packet_valid && !parity_done) begin
                    parity_done <= 1'b1;
                end
            end 
            
            // Parity 
            if (detect_add) begin
                calc_parity <= 8'h00;
            end
            else if (lfd_state) begin
                calc_parity <= calc_parity ^ hold_header; 
            end
            else if (ld_state && !fifo_full && packet_valid) begin
                calc_parity <= calc_parity ^ data_in;     
            end
            else if (lp_state && !fifo_full) begin
                packet_parity <= data_in;                
            end 
      
            //err
            if (lp_state) begin
                if (calc_parity != data_in)
                    err <= 1'b1;  
                else
                    err <= 1'b0;  
            end
            else begin
                err <= 1'b0;     
            end
        end
    end
endmodule

//fsm
module router_fsm (
    input clock,
    input resetn,
    input packet_valid,
    input [1:0] data_in,      
    input fifo_full,
    input fifo_empty,
    input parity_done,
    input low_packet_valid,
    
    output reg suspend_data,
    output reg write_enb_reg,
    output reg detect_add,
    output reg ld_state,
    output reg lp_state,
    output reg laf_state,
    output reg lfd_state,
    output reg full_state,
    output reg reset_int_reg);

    parameter DECODE_ADDRESS     = 3'b000,
              WAIT_TILL_EMPTY    = 3'b001,
              LOAD_FIRST_DATA    = 3'b010,
              LOAD_DATA          = 3'b011,
              LOAD_PARITY        = 3'b100,
              FIFO_FULL_STATE    = 3'b101,
              LOAD_AFTER_FULL    = 3'b110,
              CHECK_PARITY_ERROR = 3'b111;

    reg [2:0] present_state, next_state;

    always @(posedge clock) begin
        if (!resetn)
            present_state <= DECODE_ADDRESS;
        else
            present_state <= next_state;
    end
    always @(*) begin
        next_state = present_state; 
        
        case (present_state)
            DECODE_ADDRESS: begin
                if (packet_valid && (data_in < 2'b11)) begin
                    if (fifo_empty)
                        next_state = LOAD_FIRST_DATA;
                    else
                        next_state = WAIT_TILL_EMPTY;
                end
                else begin
                    next_state = DECODE_ADDRESS;
                end
            end
            
            WAIT_TILL_EMPTY: begin
                if (fifo_empty)
                    next_state = LOAD_FIRST_DATA;
                else
                    next_state = WAIT_TILL_EMPTY;
            end
            
            LOAD_FIRST_DATA: begin
                next_state = LOAD_DATA;
            end
            
            LOAD_DATA: begin
                if (fifo_full)
                    next_state = FIFO_FULL_STATE;
                else if (!packet_valid)
                    next_state = LOAD_PARITY;
                else
                    next_state = LOAD_DATA;
            end
            
            FIFO_FULL_STATE: begin
                if (!fifo_full)
                    next_state = LOAD_AFTER_FULL;
                else
                    next_state = FIFO_FULL_STATE;
            end
            
            LOAD_AFTER_FULL: begin
                if (parity_done)
                    next_state = CHECK_PARITY_ERROR;
                else if (low_packet_valid)
                    next_state = LOAD_PARITY;
                else
                    next_state = LOAD_DATA;
            end
            
            LOAD_PARITY: begin
                if (fifo_full)
                    next_state = FIFO_FULL_STATE;
                else
                    next_state = CHECK_PARITY_ERROR;
            end
            
            CHECK_PARITY_ERROR: begin
                next_state = DECODE_ADDRESS; 
            end
            
            default: next_state = DECODE_ADDRESS;
        endcase
    end
    always @(*) begin
        
        detect_add    = 1'b0;
        lfd_state     = 1'b0;
        ld_state      = 1'b0;
        lp_state      = 1'b0;
        laf_state     = 1'b0;
        full_state    = 1'b0;
        reset_int_reg = 1'b0;
        write_enb_reg = 1'b0;
        suspend_data  = 1'b0;
        
        case (present_state)
            DECODE_ADDRESS: begin
                detect_add = 1'b1;
            end
            
            LOAD_FIRST_DATA: begin
                lfd_state    = 1'b1;
                suspend_data = 1'b1;
            end
            
            LOAD_DATA: begin
                ld_state      = 1'b1;
                write_enb_reg = 1'b1;
               
            end
            
            LOAD_PARITY: begin
                lp_state      = 1'b1;
                suspend_data  = 1'b1;
                write_enb_reg = 1'b1;
            end
            
            FIFO_FULL_STATE: begin
                full_state   = 1'b1;
                suspend_data = 1'b1;
                
            end
            
            LOAD_AFTER_FULL: begin
                laf_state     = 1'b1;
                suspend_data  = 1'b1;
                write_enb_reg = 1'b1;
            end
            
            WAIT_TILL_EMPTY: begin
                suspend_data = 1'b1;
                
            end
            
            CHECK_PARITY_ERROR: begin
                reset_int_reg = 1'b1;
            end
        endcase
    end

endmodule

//top
module router_top (
    input clk,
    input resetn,
    input packet_valid,
    input [7:0] data_in,
    input read_enb_0,
    input read_enb_1,
    input read_enb_2,
    
    output [7:0] data_out_0,
    output [7:0] data_out_1,
    output [7:0] data_out_2,
    output vld_out_0,
    output vld_out_1,
    output vld_out_2,
    output err,
    output busy);

    wire detect_add, write_enb_reg;
    wire ld_state, lfd_state, lp_state, laf_state, full_state, reset_int_reg;
    wire fifo_empty, fifo_full;
    wire [2:0] write_enb;
    wire [7:0] reg_dout; 
    wire parity_done, low_packet_valid;
    wire full_0, full_1, full_2;
    wire empty_0, empty_1, empty_2;

    router_fsm FSM_INST (
        .clock(clk),
        .resetn(resetn),
        .packet_valid(packet_valid),
        .data_in(data_in[1:0]),        
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .parity_done(parity_done),
        .low_packet_valid(low_packet_valid),
        
        .suspend_data(busy),           
        .write_enb_reg(write_enb_reg),
        .detect_add(detect_add),
        .ld_state(ld_state),
        .lp_state(lp_state),
        .laf_state(laf_state),
        .lfd_state(lfd_state),
        .full_state(full_state),
        .reset_int_reg(reset_int_reg));

    router_reg REG_INST (
        .clk(clk),
        .resetn(resetn),
        .packet_valid(packet_valid),
        .data_in(data_in),
        .fifo_full(fifo_full),
        .detect_add(detect_add),
        .ld_state(ld_state),
        .lfd_state(lfd_state),
        .lp_state(lp_state),
        .laf_state(laf_state),
        .reset_int_reg(reset_int_reg),
        
        .dout(reg_dout),               
        .err(err),
        .parity_done(parity_done),
        .low_packet_valid(low_packet_valid));

    fifosyn SYN_INST (
        .clk(clk),
        .rst(resetn),                  
        .detect_add(detect_add),
        .full_0(full_0),
        .full_1(full_1),
        .full_2(full_2),
        .empty_0(empty_0),
        .empty_1(empty_1),
        .empty_2(empty_2),
        .write_enb_reg(write_enb_reg),
        .data(data_in[1:0]),           
        
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .vld_out_0(vld_out_0),
        .vld_out_1(vld_out_1),
        .vld_out_2(vld_out_2),
        .write_enb(write_enb));

    fifos FIFO_0 (
        .clk(clk),
        .rst(resetn),
        .we(write_enb[0]),             
        .re(read_enb_0),               
        .din(reg_dout),                
        
        .full(full_0),
        .empty(empty_0),
        .dout(data_out_0));

    fifos FIFO_1 (
        .clk(clk),
        .rst(resetn),
        .we(write_enb[1]),
        .re(read_enb_1),
        .din(reg_dout),
        
        .full(full_1),
        .empty(empty_1),
        .dout(data_out_1));

    fifos FIFO_2 (
        .clk(clk),
        .rst(resetn),
        .we(write_enb[2]),
        .re(read_enb_2),
        .din(reg_dout),
        
        .full(full_2),
        .empty(empty_2),
        .dout(data_out_2));

endmodule