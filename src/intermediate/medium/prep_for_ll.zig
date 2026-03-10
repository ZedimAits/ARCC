// ─────────────────────────────────────────────────────────────────────
// SPDX-License-Identifier: Apache-2.0
//
// ARCC - Advanced Retargetable Compiler Collection - Version 0.1.0
//
// Copyright (C) 2026 Cedric Beck
// Copyright (C) 2026 Felix Koppe <fkoppe@web.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// ─────────────────────────────────────────────────────────────────────

const mlir = @import("mlir.zig");

pub const PrepForLLError = error{
    LLPrepRequiresSelectLowering,
    LLPrepRequiresSwitchLowering,
    LLPrepRequiresPhiLowering,
    LLPrepRequiresAggregateLowering,
    LLPrepRequiresLoopLowering,
    LLPrepRequiresHeapLowering,
    LLPrepRequiresGlobalLowering,
    LLPrepRequiresExternLowering,
};

// This pass defines the contract between MLIR and LLIR.
// After this check succeeds, lowering to LLIR may assume that only backend-near ops remain.
pub fn validateReadyForLL(ml_graph: *const mlir.MLGraph) PrepForLLError!void {
    for (ml_graph.insts.items) |inst| {
        switch (inst.data) {
            .const_,
            .load,
            .store,
            .addr_of,
            .index_addr,
            .cast,
            .unary,
            .binary,
            .cmp,
            .call,
            .ret,
            .br,
            .cond_br,
            .alloc_stack,
            => {},
            .select => return error.LLPrepRequiresSelectLowering,
            .switch_ => return error.LLPrepRequiresSwitchLowering,
            .phi => return error.LLPrepRequiresPhiLowering,
            .aggregate_make, .extract, .insert => return error.LLPrepRequiresAggregateLowering,
            .loop_ => return error.LLPrepRequiresLoopLowering,
            .alloc_heap, .free => return error.LLPrepRequiresHeapLowering,
            .global => return error.LLPrepRequiresGlobalLowering,
            .extern_func => return error.LLPrepRequiresExternLowering,
        }
    }
}
