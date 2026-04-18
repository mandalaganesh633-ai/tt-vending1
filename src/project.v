// // /*
// //  * Copyright (c) 2024 Mandala Ganesh
// //  * SPDX-License-Identifier: Apache-2.0
// //  */

// // `default_nettype none

// // module tt_um_example (
// //     input  wire [7:0] ui_in,    // Dedicated inputs
// //     output wire [7:0] uo_out,   // Dedicated outputs
// //     input  wire [7:0] uio_in,   // IOs: Input path
// //     output wire [7:0] uio_out,  // IOs: Output path
// //     output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
// //     input  wire       ena,      // always 1 when the design is powered, so you can ignore it
// //     input  wire       clk,      // clock
// //     input  wire       rst_n     // reset_n - low to reset
// // );

// //   // All output pins must be assigned. If not used, assign to 0.
// //   assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
// //   assign uio_out = 0;
// //   assign uio_oe  = 0;

// //   // List all unused inputs to prevent warnings
// //   wire _unused = &{ena, clk, rst_n, 1'b0};

// // endmodule

// /*
//  * Smart Vending Machine — Tiny Tapeout Wrapper
//  */

// `default_nettype none

// module tt_um_example (
//     input  wire [7:0] ui_in,
//     output wire [7:0] uo_out,
//     input  wire [7:0] uio_in,
//     output wire [7:0] uio_out,
//     output wire [7:0] uio_oe,
//     input  wire       ena,
//     input  wire       clk,
//     input  wire       rst_n
// );

//     // ================= INPUT DECODE =================
//     wire [1:0] coin_type  = ui_in[1:0];
//     wire       coin_valid = ui_in[2];
//     wire [1:0] prod_sel   = ui_in[4:3];
//     wire       cancel_btn = ui_in[5];

//     // ================= OUTPUT WIRES =================
//     wire [6:0] seg_units;
//     wire [6:0] seg_tens;
//     wire dispense_product;

//     wire [1:0] dispense_item;
//     wire led_insert, led_ready, led_busy, led_error, led_refund;
//     wire [2:0] dbg_state;
//     wire [7:0] dbg_total;

//     // ================= DUT =================
//     smart_vending_machine dut (
//         .clk(clk),
//         .rst_n(rst_n),
//         .coin_valid(coin_valid),
//         .coin_type(coin_type),
//         .prod_sel(prod_sel),
//         .cancel_btn(cancel_btn),

//         .seg_tens(seg_tens),
//         .seg_units(seg_units),

//         .dispense_product(dispense_product),
//         .dispense_item(dispense_item),

//         .led_insert(led_insert),
//         .led_ready(led_ready),
//         .led_busy(led_busy),
//         .led_error(led_error),
//         .led_refund(led_refund),

//         .dbg_state(dbg_state),
//         .dbg_total(dbg_total)
//     );

//     // ================= OUTPUT MAPPING =================
//     assign uo_out[6:0] = seg_units;       // show units digit
//     assign uo_out[7]   = dispense_product;

//     // ================= UNUSED IO =================
//     assign uio_out = 8'b0;
//     assign uio_oe  = 8'b0;

//     wire _unused = &{ena, uio_in, seg_tens, dbg_state, dbg_total, 1'b0};

// endmodule

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

    // ---- Internal Wires ----
    wire        coin_valid = ui_in[0];
    wire [1:0]  coin_type  = ui_in[2:1];
    wire [1:0]  prod_sel   = ui_in[4:3];
    wire        cancel_btn = ui_in[5];

    wire [6:0]  seg_tens, seg_units;
    wire        dispense_product;
    wire [1:0]  dispense_item;
    wire        led_insert, led_ready, led_busy, led_error, led_refund;
    wire [2:0]  dbg_state;
    wire [7:0]  dbg_total;

    // ---- Pin Mapping ----
    // Units Segment + Dispense Product
    assign uo_out[6:0] = seg_units;
    assign uo_out[7]   = dispense_product;

    // Tens Segment + Busy LED
    assign uio_out[6:0] = seg_tens;
    assign uio_out[7]   = led_busy;
    assign uio_oe       = 8'b11111111; // All bidirectional pins used as outputs

    // Unused inputs to prevent warnings
    wire _unused = &{ena, ui_in[7:6], uio_in, 1'b0};

    // ---- Core Vending Machine Logic ----

    // coin_decoder → money_accumulator
    wire [3:0]  coin_value;
    wire        value_valid;
    
    // money_accumulator → fsm_controller
    wire [7:0]  total;
    wire        clear_acc;

    // product_selector → fsm_controller
    wire [3:0]  price;
    wire        valid_sel;

    // coin_inventory ports
    wire        add_valid;
    wire [1:0]  add_denom;
    wire        sub_valid;
    wire [1:0]  sub_denom;
    wire [3:0]  sub_count;
    wire [3:0]  inv_d1, inv_d2, inv_d5, inv_d10;

    // change_optimizer ports
    wire        change_start;
    wire [7:0]  change_amount;
    wire        change_done, change_error;
    wire [3:0]  disp_d1, disp_d2, disp_d5, disp_d10;

    // bcd → seg
    wire [3:0]  bcd_tens, bcd_units;

    assign add_valid = value_valid;
    assign add_denom = coin_type;

    // ---- Sub-module Instances ----

    coin_decoder u_coin_dec (
        .clk        (clk),
        .rst_n      (rst_n),
        .coin_valid (coin_valid),
        .coin_type  (coin_type),
        .coin_value (coin_value),
        .value_valid(value_valid)
    );

    money_accumulator u_acc (
        .clk        (clk),
        .rst_n      (rst_n),
        .coin_value (coin_value),
        .value_valid(value_valid),
        .clear_acc  (clear_acc),
        .total      (total)
    );

    product_selector u_prod (
        .prod_sel  (prod_sel),
        .price     (price),
        .valid_sel (valid_sel)
    );

    coin_inventory u_inv (
        .clk      (clk),
        .rst_n    (rst_n),
        .add_valid(add_valid),
        .add_denom(add_denom),
        .sub_valid(sub_valid),
        .sub_denom(sub_denom),
        .sub_count(sub_count),
        .inv_d1   (inv_d1),
        .inv_d2   (inv_d2),
        .inv_d5   (inv_d5),
        .inv_d10  (inv_d10)
    );

    change_optimizer u_opt (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (change_start),
        .change_amount(change_amount),
        .inv_d1       (inv_d1),
        .inv_d2       (inv_d2),
        .inv_d5       (inv_d5),
        .inv_d10      (inv_d10),
        .disp_d1      (disp_d1),
        .disp_d2      (disp_d2),
        .disp_d5      (disp_d5),
        .disp_d10     (disp_d10),
        .done         (change_done),
        .error        (change_error)
    );

    fsm_controller u_fsm (
        .clk             (clk),
        .rst_n           (rst_n),
        .total           (total),
        .price           (price),
        .valid_sel       (valid_sel),
        .cancel_btn      (cancel_btn),
        .prod_sel        (prod_sel),
        .change_done     (change_done),
        .change_error    (change_error),
        .disp_d1         (disp_d1),
        .disp_d2         (disp_d2),
        .disp_d5         (disp_d5),
        .disp_d10        (disp_d10),
        .change_start    (change_start),
        .change_amount   (change_amount),
        .sub_valid       (sub_valid),
        .sub_denom       (sub_denom),
        .sub_count       (sub_count),
        .clear_acc       (clear_acc),
        .dispense_product(dispense_product),
        .dispense_item   (dispense_item),
        .led_insert      (led_insert),
        .led_ready       (led_ready),
        .led_busy        (led_busy),
        .led_error       (led_error),
        .led_refund      (led_refund),
        .dbg_state       (dbg_state)
    );

    bcd_converter u_bcd (
        .bin  (total),
        .tens (bcd_tens),
        .units(bcd_units)
    );

    seg7_driver u_seg_tens (
        .digit(bcd_tens),
        .seg  (seg_tens)
    );

    seg7_driver u_seg_units (
        .digit(bcd_units),
        .seg  (seg_units)
    );

endmodule


// ============================================================================
//  INTERNAL MODULES
// ============================================================================

module coin_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        coin_valid,
    input  wire [1:0]  coin_type,
    output reg  [3:0]  coin_value,
    output reg         value_valid
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coin_value  <= 4'd0;
            value_valid <= 1'b0;
        end else begin
            value_valid <= coin_valid;
            if (coin_valid) begin
                case (coin_type)
                    2'b00:  coin_value <= 4'd1;
                    2'b01:  coin_value <= 4'd2;
                    2'b10:  coin_value <= 4'd5;
                    2'b11:  coin_value <= 4'd10;
                    default: coin_value <= 4'd0;
                endcase
            end else begin
                coin_value <= 4'd0;
            end
        end
    end
endmodule

module money_accumulator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  coin_value,
    input  wire        value_valid,
    input  wire        clear_acc,
    output reg  [7:0]  total
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total <= 8'd0;
        end else if (clear_acc) begin
            total <= 8'd0;
        end else if (value_valid) begin
            if (total + {4'd0, coin_value} > 8'd255)
                total <= 8'd255;
            else
                total <= total + {4'd0, coin_value};
        end
    end
endmodule

module product_selector (
    input  wire [1:0]  prod_sel,
    output reg  [3:0]  price,
    output reg         valid_sel
);
    always @(*) begin
        case (prod_sel)
            2'b00: begin price = 4'd5;  valid_sel = 1'b1; end
            2'b01: begin price = 4'd7;  valid_sel = 1'b1; end
            2'b10: begin price = 4'd9;  valid_sel = 1'b1; end
            2'b11: begin price = 4'd10; valid_sel = 1'b1; end
            default: begin price = 4'd0; valid_sel = 1'b0; end
        endcase
    end
endmodule

module coin_inventory (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        add_valid,
    input  wire [1:0]  add_denom,
    input  wire        sub_valid,
    input  wire [1:0]  sub_denom,
    input  wire [3:0]  sub_count,
    output wire [3:0]  inv_d1, inv_d2, inv_d5, inv_d10
);
    reg [3:0] inv [0:3];
    assign inv_d1  = inv[0];
    assign inv_d2  = inv[1];
    assign inv_d5  = inv[2];
    assign inv_d10 = inv[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inv[0] <= 4'd10; inv[1] <= 4'd8;
            inv[2] <= 4'd6;  inv[3] <= 4'd4;
        end else begin
            if (add_valid) begin
                if (inv[add_denom] < 4'd15)
                    inv[add_denom] <= inv[add_denom] + 4'd1;
            end
            if (sub_valid) begin
                if (inv[sub_denom] >= sub_count)
                    inv[sub_denom] <= inv[sub_denom] - sub_count;
                else
                    inv[sub_denom] <= 4'd0;
            end
        end
    end
endmodule

module change_optimizer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [7:0]  change_amount,
    input  wire [3:0]  inv_d1, inv_d2, inv_d5, inv_d10,
    output reg  [3:0]  disp_d1, disp_d2, disp_d5, disp_d10,
    output reg         done,
    output reg         error
);
    localparam [2:0] CO_IDLE=3'd0, CO_D10=3'd1, CO_D5=3'd2, CO_D2=3'd3, CO_D1=3'd4, CO_DONE=3'd5;
    reg [2:0] state;
    reg [7:0] rem;
    reg [3:0] s_d1, s_d2, s_d5, s_d10;

    function automatic [3:0] use_coins;
        input [7:0] rem_in;
        input [3:0] val;
        input [3:0] avail;
        reg   [7:0] needed;
        begin
            needed = rem_in / val;
            if (needed > {4'd0, avail}) use_coins = avail;
            else use_coins = needed[3:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= CO_IDLE; done <= 1'b0; error <= 1'b0;
            disp_d1<=0; disp_d2<=0; disp_d5<=0; disp_d10<=0;
        end else begin
            done <= 1'b0; error <= 1'b0;
            case (state)
                CO_IDLE: if (start) begin
                    s_d1<=inv_d1; s_d2<=inv_d2; s_d5<=inv_d5; s_d10<=inv_d10;
                    rem <= change_amount; disp_d1<=0; disp_d2<=0; disp_d5<=0; disp_d10<=0;
                    state <= (change_amount == 0) ? CO_DONE : CO_D10;
                end
                CO_D10: begin
                    disp_d10 <= use_coins(rem, 10, s_d10);
                    rem <= rem - (use_coins(rem, 10, s_d10) * 10);
                    state <= CO_D5;
                end
                CO_D5: begin
                    disp_d5 <= use_coins(rem, 5, s_d5);
                    rem <= rem - (use_coins(rem, 5, s_d5) * 5);
                    state <= CO_D2;
                end
                CO_D2: begin
                    disp_d2 <= use_coins(rem, 2, s_d2);
                    rem <= rem - (use_coins(rem, 2, s_d2) * 2);
                    state <= CO_D1;
                end
                CO_D1: begin
                    disp_d1 <= use_coins(rem, 1, s_d1);
                    rem <= rem - use_coins(rem, 1, s_d1);
                    state <= CO_DONE;
                end
                CO_DONE: begin done <= 1'b1; error <= (rem != 0); state <= CO_IDLE; end
                default: state <= CO_IDLE;
            endcase
        end
    end
endmodule

module bcd_converter (
    input  wire [7:0]  bin,
    output reg  [3:0]  tens,
    output reg  [3:0]  units
);
    reg [15:0] scratch;
    integer i;
    always @(*) begin
        scratch = {8'd0, bin};
        for (i=0; i<8; i=i+1) begin
            if (scratch[11:8]  >= 5) scratch[11:8]  = scratch[11:8]  + 3;
            if (scratch[15:12] >= 5) scratch[15:12] = scratch[15:12] + 3;
            scratch = scratch << 1;
        end
        tens = scratch[15:12]; units = scratch[11:8];
    end
endmodule

module seg7_driver (
    input  wire [3:0]  digit,
    output reg  [6:0]  seg
);
    always @(*) begin
        case (digit)
            4'd0: seg = 7'b0111111;
            4'd1: seg = 7'b0000110;
            4'd2: seg = 7'b1011011;
            4'd3: seg = 7'b1001111;
            4'd4: seg = 7'b1100110;
            4'd5: seg = 7'b1101101;
            4'd6: seg = 7'b1111101;
            4'd7: seg = 7'b0000111;
            4'd8: seg = 7'b1111111;
            4'd9: seg = 7'b1101111;
            default: seg = 7'b1000000;
        endcase
    end
endmodule

module fsm_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  total,
    input  wire [3:0]  price,
    input  wire        valid_sel,
    input  wire        cancel_btn,
    input  wire [1:0]  prod_sel,
    input  wire        change_done,
    input  wire        change_error,
    input  wire [3:0]  disp_d1, disp_d2, disp_d5, disp_d10,
    output reg         change_start,
    output reg  [7:0]  change_amount,
    output reg         sub_valid,
    output reg  [1:0]  sub_denom,
    output reg  [3:0]  sub_count,
    output reg         clear_acc,
    output reg         dispense_product,
    output reg  [1:0]  dispense_item,
    output reg         led_insert, led_ready, led_busy, led_error, led_refund,
    output wire [2:0]  dbg_state
);
    localparam [2:0] S_IDLE=0, S_ACCEPT=1, S_DISPENSE=2, S_CALC_CHANGE=3, S_GIVE_CHANGE=4, S_REFUND=5, S_ERROR=6;
    reg [2:0] state;
    reg [1:0] chg_step;
    reg [3:0] r_d1, r_d2, r_d5, r_d10;

    assign dbg_state = state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; chg_step <= 0; change_start <= 0; clear_acc <= 0; dispense_product <= 0;
            led_insert <= 1; led_ready <= 0; led_busy <= 0; led_error <= 0; led_refund <= 0;
        end else begin
            sub_valid <= 0; clear_acc <= 0; dispense_product <= 0; change_start <= 0;
            case (state)
                S_IDLE: begin
                    led_insert <= 1; led_ready <= 0; led_busy <= 0; led_error <= 0; led_refund <= 0;
                    if (total > 0 && valid_sel) state <= S_ACCEPT;
                end
                S_ACCEPT: begin
                    led_insert <= 0; led_busy <= 1;
                    if (cancel_btn) state <= S_REFUND;
                    else if (total >= {4'd0, price}) begin led_ready <= 1; state <= S_DISPENSE; end
                end
                S_DISPENSE: begin
                    dispense_product <= 1; dispense_item <= prod_sel;
                    if (total == {4'd0, price}) begin clear_acc <= 1; state <= S_IDLE; end
                    else begin change_amount <= total - price; state <= S_CALC_CHANGE; end
                end
                S_CALC_CHANGE: begin
                    change_start <= 1;
                    if (change_done) begin
                        if (change_error) state <= S_ERROR;
                        else begin r_d1<=disp_d1; r_d2<=disp_d2; r_d5<=disp_d5; r_d10<=disp_d10; chg_step<=0; state<=S_GIVE_CHANGE; end
                    end
                end
                S_GIVE_CHANGE: begin
                    case (chg_step)
                        0: begin if (r_d10>0) begin sub_valid<=1; sub_denom<=3; sub_count<=r_d10; end chg_step<=1; end
                        1: begin if (r_d5>0)  begin sub_valid<=1; sub_denom<=2; sub_count<=r_d5;  end chg_step<=2; end
                        2: begin if (r_d2>0)  begin sub_valid<=1; sub_denom<=1; sub_count<=r_d2;  end chg_step<=3; end
                        3: begin if (r_d1>0)  begin sub_valid<=1; sub_denom<=0; sub_count<=r_d1;  end clear_acc<=1; state<=S_IDLE; end
                    endcase
                end
                S_REFUND: begin
                    led_refund <= 1; change_amount <= total; change_start <= 1;
                    if (change_done) begin
                        if (change_error) state <= S_ERROR;
                        else begin r_d1<=disp_d1; r_d2<=disp_d2; r_d5<=disp_d5; r_d10<=disp_d10; chg_step<=0; state<=S_GIVE_CHANGE; end
                    end
                end
                S_ERROR: begin led_error<=1; led_busy<=0; led_ready<=0; led_refund<=0; end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
