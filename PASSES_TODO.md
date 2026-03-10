# Passes TODO

## Suggested Priority

1. [ ] `type_check`
2. [ ] `const_prop`
3. [ ] `dead_code_elim`
4. [ ] `cfg_simplify`
5. [ ] transformierendes `prepareForLL`
6. [ ] `instruction_select`
7. [ ] `regalloc`

## Passes by level

### HLIR

- [ ] `name_resolution`
- [ ] `type_check`
- [ ] `constant_folding`
- [ ] `desugar_control_flow`
- [ ] `dead_stmt_elim`
- [ ] `canonicalize_exprs`

### MLIR

- [ ] `mem2reg`
- [ ] `const_prop`
- [ ] `cse`
- [ ] `dead_code_elim`
- [ ] `cfg_simplify`
- [ ] `inline`
- [ ] `loop_simplify`
- [ ] `licm`
- [ ] `strength_reduce`
- [ ] `scalar_replacement`
- [ ] `canonicalize_calls`
- [ ] `lower_aggregates`
- [ ] `lower_switch`
- [ ] `lower_select`
- [ ] `lower_phi`
- [ ] `prepareForLL`

### ML -> LL

- [ ] `legalize_for_ll`
- [ ] `abi_lowering`
- [ ] `stack_slot_insertion`
- [ ] `address_mode_lowering`
- [ ] `runtime_call_expansion`
- [ ] `global_symbol_lowering`

### LLIR

- [ ] `copy_propagation`
- [ ] `peephole`
- [ ] `block_layout`
- [ ] `branch_simplify`
- [ ] `instruction_select`
- [ ] `register_class_assignment`
- [ ] `stack_frame_layout`
- [ ] `ssa_destruction`
- [ ] `regalloc`
- [ ] `spill_insertion`
- [ ] `prologue_epilogue_insertion`

### Linear

- [ ] `block_ordering`
- [ ] `critical_edge_split`
- [ ] `parallel_copy_resolution`
- [ ] `late_peephole`
- [ ] `bundle_instructions`

### Emission

- [ ] `asm_print`
- [ ] `object_emission`