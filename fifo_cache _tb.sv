`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.02.2025 21:36:19
// Design Name: 
// Module Name: fifo_cache _tb
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


module fifo_cache_tb;

  // Parameters
  parameter CACHE_SIZE = 4;
  parameter ADDR_WIDTH = 8;

  // Signals
  logic clk;
  logic reset;
  logic [ADDR_WIDTH-1:0] address;
  logic read_write;
  logic hit;
  logic [ADDR_WIDTH-1:0] evicted_address;

  // Reference Model
  logic [ADDR_WIDTH-1:0] golden_cache[CACHE_SIZE];
  int valid_entries = 0;
  logic expected_hit;
  logic [ADDR_WIDTH-1:0] expected_evicted_addr;
  logic eviction_occurred;

  // Scoreboard Buffers
  logic expected_hits[$];
  logic [ADDR_WIDTH-1:0] expected_evicted_addrs[$];

  // Functional Coverage
  covergroup cache_cov;
    coverpoint read_write { bins rd = {0}; bins wr = {1}; }
    coverpoint hit { bins hit = {1}; bins miss = {0}; }
    coverpoint evicted_address { bins evicts[] = {[0:255]}; }
    cross read_write, hit;
  endgroup

  cache_cov cov_inst = new();

  // DUT Instantiation
  fifo_cache #(CACHE_SIZE, ADDR_WIDTH) dut (
    .clk(clk),
    .reset(reset),
    .address(address),
    .read_write(read_write),
    .hit(hit),
    .evicted_address(evicted_address)
  );

  // Clock Generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset & Initialization
  initial begin
    reset = 1;
    address = 0;
    read_write = 0;
    valid_entries = 0;
    foreach (golden_cache[i]) golden_cache[i] = 0;
    #20 reset = 0;
  end

  // Reference Model (FIFO Logic)
  task update_ref_model(input logic [ADDR_WIDTH-1:0] addr, input logic rw);
    expected_hit = 0;
    eviction_occurred = 0;
    expected_evicted_addr = 0;

    // Check for hit
    foreach (golden_cache[i]) begin
      if (golden_cache[i] == addr) expected_hit = 1;
    end

    // Handle writes
    if (rw && !expected_hit) begin
      if (valid_entries < CACHE_SIZE) begin
        golden_cache[valid_entries] = addr;
        valid_entries++;
      end else begin
        // Evict oldest entry
        eviction_occurred = 1;
        expected_evicted_addr = golden_cache[0];
        // Shift entries left
        for (int i = 0; i < CACHE_SIZE-1; i++) golden_cache[i] = golden_cache[i+1];
        golden_cache[CACHE_SIZE-1] = addr;
      end
    end
  endtask

  // Driver Task
  task driver(input logic [ADDR_WIDTH-1:0] addr, input logic rw);
    @(posedge clk);
    address <= addr;
    read_write <= rw;
    update_ref_model(addr, rw);

    fork
      begin
        #1; // Allow for signal propagation
        expected_hits.push_back(expected_hit);
        if (eviction_occurred)
          expected_evicted_addrs.push_back(expected_evicted_addr);
      end
    join_none

    cov_inst.sample();
  endtask

  task scoreboard();
  forever begin
    @(posedge clk);

    // Check hit/miss
    if (expected_hits.size() > 0) begin
      logic exp_hit = expected_hits.pop_front();
      if (hit !== exp_hit) begin
        $display("[ERROR] %t | Addr: %h | Exp_HIT: %b | DUT_HIT: %b | CACHE=%p",
                $time, address, exp_hit, hit, golden_cache);
      end
    end

    // Check evictions ONLY during writes
    if (read_write && evicted_address !== 0) begin
      if (expected_evicted_addrs.size() > 0) begin
        logic [ADDR_WIDTH-1:0] exp_evict = expected_evicted_addrs.pop_front();
        if (evicted_address !== exp_evict) begin
          $display("[ERROR] %t | Eviction Mismatch! Exp: %h | DUT: %h",
                  $time, exp_evict, evicted_address);
        end
      end else begin
        $display("[ERROR] %t | Unexpected Eviction: %h", $time, evicted_address);
      end
    end
  end
endtask
  // Monitor Task
  task monitor();
    forever begin
      @(posedge clk);
      $display("%t | ADDR=%h | RW=%b | HIT=%b | EVICT=%h | CACHE=%p",
              $time, address, read_write, hit, evicted_address, golden_cache);
    end
  endtask

  // Assertion Check
  always @(posedge clk) begin
    if (hit) begin
      automatic logic found = 0;
      foreach (golden_cache[i]) found |= (golden_cache[i] == address);
      assert(found) else $error("[ASSERTION] False hit detected for addr %h", address);
    end
  end

  // Test Sequence
  initial begin
    fork
      monitor();
      scoreboard();
    join_none

    #25; // Post-reset stabilization

    // Phase 1: Fill cache
    driver(8'hA1, 1); // Write A1
    driver(8'hA2, 1); // Write A2
    driver(8'hA3, 1); // Write A3
    driver(8'hA4, 1); // Write A4

    // Phase 2: Trigger evictions
    driver(8'hA5, 1); // Evict A1
    driver(8'hA6, 1); // Evict A2
    driver(8'hA7, 1); // Evict A3
    driver(8'hA8, 1); // Evict A4

    // Phase 3: Verify hits/misses
    driver(8'hA5, 0); // Should hit
    driver(8'hA1, 0); // Should miss
    driver(8'hA6, 0); // Should hit
    driver(8'hA2, 0); // Should miss

    #100;
    $display("Final Coverage: %.2f%%", cov_inst.get_coverage());
    $finish;
  end

endmodule