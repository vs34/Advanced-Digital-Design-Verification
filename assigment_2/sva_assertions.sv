// sva_assertions.sv
// SystemVerilog Assertions for simple_cpu verification

`timescale 1ns / 1ps

module sva_assertions (
    input logic clk,
    input logic rst_n,
    input logic instr_valid,
    input logic [15:0] instr,
    input logic instr_ready,
    input logic [7:0] mem_rdata,
    input logic mem_ready,
    input logic mem_req,
    input logic mem_we,
    input logic [7:0] mem_addr,
    input logic [7:0] mem_wdata,
    input logic done,
    input logic [3:0] flags
);

  // Extract opcode for assertion checks
  wire [3:0] opcode = instr[15:12];

  // Track when instruction is accepted
  logic instr_accepted;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) instr_accepted <= 1'b0;
    else instr_accepted <= instr_valid && instr_ready;
  end

  //==========================================================================
  // ASSERTION 1: All instructions complete within 5 cycles
  //==========================================================================
  // When an instruction is accepted (instr_valid && instr_ready),
  // the CPU must return to IDLE (instr_ready=1) within 5 clock cycles

  property p_instruction_latency_5cycles;
    @(posedge clk) disable iff (!rst_n) (instr_valid && instr_ready) |-> ##[1:5] instr_ready;
  endproperty

  assert_instr_latency_5cycles :
  assert property (p_instruction_latency_5cycles)
  else $error("[%0t] ASSERTION FAILED: Instruction did not complete within 5 cycles", $time);

  cover_instr_latency_5cycles :
  cover property (p_instruction_latency_5cycles);


  //==========================================================================
  // ASSERTION 2: NOP completes in exactly 3 cycles (IDLE->DECODE->EXEC->IDLE)
  //==========================================================================
  property p_nop_latency;
    @(posedge clk) disable iff (!rst_n)
    (instr_valid && instr_ready && opcode == 4'h0) |-> ##3 instr_ready;
  endproperty

  assert_nop_latency :
  assert property (p_nop_latency)
  else $error("[%0t] NOP did not complete in 3 cycles", $time);

  cover_nop_latency :
  cover property (p_nop_latency);


  //==========================================================================
  // ASSERTION 3: ALU instructions complete in exactly 4 cycles
  // (IDLE->DECODE->EXEC->WB->IDLE)
  //==========================================================================
  property p_alu_latency;
    @(posedge clk) disable iff (!rst_n)
    (instr_valid && instr_ready && (opcode inside {4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8}))
    |-> ##4 instr_ready;
  endproperty

  assert_alu_latency :
  assert property (p_alu_latency)
  else $error("[%0t] ALU instruction did not complete in 4 cycles (opcode=0x%h)", $time, opcode);

  cover_alu_latency :
  cover property (p_alu_latency);


  //==========================================================================
  // ASSERTION 4: LOAD/STORE complete within 5 cycles (variable due to mem_ready)
  // (IDLE->DECODE->EXEC->MEM->IDLE, where MEM waits for mem_ready)
  //==========================================================================
  property p_mem_instr_latency;
    @(posedge clk) disable iff (!rst_n)
    (instr_valid && instr_ready && (opcode == 4'h9 || opcode == 4'hA))
    |-> ##[3:5] instr_ready;
  endproperty

  assert_mem_instr_latency :
  assert property (p_mem_instr_latency)
  else $error("[%0t] Memory instruction exceeded 5 cycles (opcode=0x%h)", $time, opcode);

  cover_mem_instr_latency :
  cover property (p_mem_instr_latency);


  //==========================================================================
  // ASSERTION 5: Branch/Jump complete in 3 cycles (IDLE->DECODE->EXEC->IDLE)
  //==========================================================================
  property p_branch_jump_latency;
    @(posedge clk) disable iff (!rst_n)
    (instr_valid && instr_ready && (opcode == 4'hB || opcode == 4'hC))
    |-> ##3 instr_ready;
  endproperty

  assert_branch_jump_latency :
  assert property (p_branch_jump_latency)
  else $error("[%0t] Branch/Jump did not complete in 3 cycles", $time);

  cover_branch_jump_latency :
  cover property (p_branch_jump_latency);


  //==========================================================================
  // ASSERTION 6: HALT completes in 3 cycles and sets done flag
  //==========================================================================
  property p_halt_latency;
    @(posedge clk) disable iff (!rst_n)
    (instr_valid && instr_ready && opcode == 4'hF)
    |-> ##3 (instr_ready && done);
  endproperty

  assert_halt_latency :
  assert property (p_halt_latency)
  else $error("[%0t] HALT did not complete in 3 cycles or done not set", $time);

  cover_halt_latency :
  cover property (p_halt_latency);


  //==========================================================================
  // ASSERTION 7: Memory request must be followed by ready within 3 cycles
  //==========================================================================
  property p_mem_response;
    @(posedge clk) disable iff (!rst_n) mem_req |-> ##[1:3] mem_ready;
  endproperty

  assert_mem_response :
  assert property (p_mem_response)
  else $error("[%0t] Memory did not respond within 3 cycles", $time);

  cover_mem_response :
  cover property (p_mem_response);


  //==========================================================================
  // ASSERTION 8: instr_ready should not be asserted when instruction is processing
  //==========================================================================
  property p_instr_ready_mutex;
    @(posedge clk) disable iff (!rst_n) (instr_valid && instr_ready) |=> !instr_ready;
  endproperty

  assert_instr_ready_mutex :
  assert property (p_instr_ready_mutex)
  else $error("[%0t] instr_ready remained high after accepting instruction", $time);

  cover_instr_ready_mutex :
  cover property (p_instr_ready_mutex);


  //==========================================================================
  // ASSERTION 9: mem_req must be deasserted after mem_ready
  //==========================================================================
  property p_mem_req_deassert;
    @(posedge clk) disable iff (!rst_n) (mem_req && mem_ready) |=> !mem_req;
  endproperty

  assert_mem_req_deassert :
  assert property (p_mem_req_deassert)
  else $error("[%0t] mem_req not deasserted after mem_ready", $time);

  cover_mem_req_deassert :
  cover property (p_mem_req_deassert);


  //==========================================================================
  // ASSERTION 10: Once done is set, it should remain set
  //==========================================================================
  property p_done_sticky;
    @(posedge clk) disable iff (!rst_n) done |=> done;
  endproperty

  assert_done_sticky :
  assert property (p_done_sticky)
  else $error("[%0t] done flag was cleared after being set", $time);

  cover_done_sticky :
  cover property (p_done_sticky);


  //==========================================================================
  // COVERAGE: Track all opcodes
  //==========================================================================
  cover property (@(posedge clk) disable iff (!rst_n)
    instr_valid && instr_ready && opcode == 4'h0);  // NOP

  cover property (@(posedge clk) disable iff (!rst_n)
    instr_valid && instr_ready && opcode == 4'h1);  // ADD

  cover property (@(posedge clk) disable iff (!rst_n)
    instr_valid && instr_ready && opcode == 4'h9);  // LOAD

  cover property (@(posedge clk) disable iff (!rst_n)
    instr_valid && instr_ready && opcode == 4'hA);  // STORE

  cover property (@(posedge clk) disable iff (!rst_n)
    instr_valid && instr_ready && opcode == 4'hF);  // HALT

endmodule


//==========================================================================
// Bind statement to connect assertions to CPU
//==========================================================================
bind simple_cpu sva_assertions sva_inst (
    .clk(clk),
    .rst_n(rst_n),
    .instr_valid(instr_valid),
    .instr(instr),
    .instr_ready(instr_ready),
    .mem_rdata(mem_rdata),
    .mem_ready(mem_ready),
    .mem_req(mem_req),
    .mem_we(mem_we),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .done(done),
    .flags(flags)
);
