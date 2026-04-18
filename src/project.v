/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // ================= INPUT MAPPING =================
    wire       coin_valid = ui_in[0];
    wire [1:0] coin_type  = ui_in[2:1];
    wire [1:0] prod_sel   = ui_in[4:3];
    wire       cancel_btn = ui_in[5];

    // ================= INTERNAL WIRES =================
    wire [6:0] seg_units, seg_tens;
    wire       dispense_product, led_busy;

    // unused inputs to avoid warnings
    wire _unused = &{ena, ui_in[7:6], uio_in, 1'b0};

    // ================= OUTPUT MAPPING =================
    assign uo_out[6:0] = seg_units;       // Units digit
    assign uo_out[7]   = dispense_product;

    assign uio_out[6:0] = seg_tens;        // Tens digit
    assign uio_out[7]   = led_busy;        // Status indicator
    assign uio_oe       = 8'b11111111;     // All bi-dir pins configured as outputs

    // ================= MODULE INSTANTIATION =================
    vending_machine_logic core (
        .clk              (clk),
        .rst_n            (rst_n),
        .coin_valid       (coin_valid),
        .coin_type        (coin_type),
        .prod_sel         (prod_sel),
        .cancel_btn       (cancel_btn),
        .seg_tens         (seg_tens),
        .seg_units        (seg_units),
        .dispense_product (dispense_product),
        .led_busy         (led_busy)
    );

endmodule

// ============================================================================
//  VENDING MACHINE CORE LOGIC
// ============================================================================
module vending_machine_logic (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        coin_valid,
    input  wire [1:0]  coin_type,
    input  wire [1:0]  prod_sel,
    input  wire        cancel_btn,
    output wire [6:0]  seg_tens,
    output wire [6:0]  seg_units,
    output wire        dispense_product,
    output wire        led_busy
);

    // Money Accumulator Logic
    reg [7:0] total;
    wire [3:0] coin_value = (coin_type == 2'b00) ? 1 : 
                            (coin_type == 2'b01) ? 2 : 
                            (coin_type == 2'b10) ? 5 : 10;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) total <= 0;
        else if (clear_acc) total <= 0;
        else if (coin_valid) total <= total + {4'd0, coin_value};
    end

    // Product Selection
    wire [3:0] price = (prod_sel == 2'b00) ? 5 : 
                       (prod_sel == 2'b01) ? 7 : 
                       (prod_sel == 2'b10) ? 9 : 10;

    // FSM States
    localparam S_IDLE = 0, S_DISPENSE = 1, S_CHANGE = 2;
    reg [1:0] state;
    reg clear_acc;
    
    assign dispense_product = (state == S_DISPENSE);
    assign led_busy = (state != S_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            clear_acc <= 0;
        end else begin
            clear_acc <= 0;
            case (state)
                S_IDLE: if (total >= {4'd0, price}) state <= S_DISPENSE;
                S_DISPENSE: state <= S_CHANGE;
                S_CHANGE: begin
                    clear_acc <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // 7-Segment Drivers
    bcd_to_7seg units_drv (.bin(total % 10), .seg(seg_units));
    bcd_to_7seg tens_drv  (.bin(total / 10), .seg(seg_tens));

endmodule

// Simple BCD to 7-Segment Decoder
module bcd_to_7seg (
    input  wire [3:0] bin,
    output reg  [6:0] seg
);
    always @(*) begin
        case (bin)
            0: seg = 7'b0111111; 1: seg = 7'b0000110; 2: seg = 7'b1011011;
            3: seg = 7'b1001111; 4: seg = 7'b1100110; 5: seg = 7'b1101101;
            6: seg = 7'b1111101; 7: seg = 7'b0000111; 8: seg = 7'b1111111;
            9: seg = 7'b1101111; default: seg = 7'b0000000;
        endcase
    end
endmodule
