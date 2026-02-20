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

pub const MlBinOp = enum {
    iadd, // integer addition (wrap/overflow semantics defined by your IR contract)
    isub, // integer subtraction (wrap/overflow semantics defined by your IR contract)
    imul, // integer multiplication (wrap/overflow semantics defined by your IR contract)
    idiv, // integer division (define: trunc toward zero? trap on div-by-zero? signed/unsigned handled elsewhere)
    imod, // integer remainder/modulo (define sign rule + div-by-zero behavior)
    fadd, // floating-point addition (IEEE-754; NaN/Inf propagate per rules)
    fsub, // floating-point subtraction (IEEE-754)
    fmul, // floating-point multiplication (IEEE-754)
    fdiv, // floating-point division (IEEE-754; div-by-zero yields Inf/NaN per rules)
    icmp_eq, // integer equality comparison -> bool (or i1); signedness handled by op choice or type flags
    icmp_ne, // integer inequality comparison -> bool (or i1)
    icmp_lt, // integer less-than comparison -> bool (signedness handled by op choice or type flags)
    icmp_le, // integer less-or-equal comparison -> bool
    icmp_gt, // integer greater-than comparison -> bool
    icmp_ge, // integer greater-or-equal comparison -> bool
    fcmp_oeq, // float ordered equal (false if either operand is NaN)
    fcmp_one, // float ordered not-equal (false if either operand is NaN)
    fcmp_olt, // float ordered less-than (false if either operand is NaN)
    fcmp_ole, // float ordered less-or-equal (false if either operand is NaN)
    fcmp_ogt, // float ordered greater-than (false if either operand is NaN)
    fcmp_oge, // float ordered greater-or-equal (false if either operand is NaN)
    band, // bitwise AND (integers / bitvectors)
    bor, // bitwise OR (integers / bitvectors)
    bxor, // bitwise XOR (integers / bitvectors)
    shl, // logical left shift (define behavior for overshift; usually mask or trap)
    lshr, // logical right shift (zero-fill)
    ashr, // arithmetic right shift (sign-extend)
};
