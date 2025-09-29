`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.02.2025 21:35:25
// Design Name: 
// Module Name: fifo_cache
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

module fifo_cache #(parameter CACHE_SIZE = 4, parameter ADDR_WIDTH = 8)(
    input logic clk,
    input logic reset,
    input logic [ADDR_WIDTH-1:0] address,
    input logic read_write,
    output logic hit,
    output logic [ADDR_WIDTH-1:0] evicted_address
);

  // Internal FIFO Cache
  logic [ADDR_WIDTH-1:0] cache [CACHE_SIZE];
  int fifo_ptr = 0; // Tracks insertion point

  // Hit Detection (Combinational)
  always_comb begin
    hit = 0;
    for (int i = 0; i < CACHE_SIZE; i++) begin
      if (cache[i] == address) hit = 1;
    end
  end

  // Cache Update (Sequential)
  always_ff @(posedge clk) begin
    if (reset) begin
      fifo_ptr <= 0;
      evicted_address <= 0;
      for (int i = 0; i < CACHE_SIZE; i++) cache[i] <= 0;
    end else begin
      // Reset evicted_address every cycle unless eviction occurs
      evicted_address <= 0;

      if (read_write && !hit) begin
        if (fifo_ptr < CACHE_SIZE) begin
          cache[fifo_ptr] <= address;
          fifo_ptr <= fifo_ptr + 1;
        end else begin
          // Evict oldest entry (FIFO)
          evicted_address <= cache[0];
          // Shift entries left
          for (int i = 0; i < CACHE_SIZE-1; i++) cache[i] <= cache[i+1];
          cache[CACHE_SIZE-1] <= address;
        end
      end
    end
  end

endmodule