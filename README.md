# ARCC - Advanced Retargetable Compiler Collection

## Introduction

ARCC is a compiler collection that maps multiple frontends into a shared IR pipeline and targets multiple backends.

**Project goals**
- Provide a retargetable compiler pipeline with clear IR boundaries.
- Support multiple source languages via dedicated frontends.
- Enable multiple outputs and execution targets from a shared *mid-level IR (MLIR)*.

**Architecture overview**
- Inputs: TinyC, SimpleC, and our own language.
- Pipeline: a central lexer feeds per-language parsers (handwritten or generated).
- Each frontend produces tokenstream, AST, then *high-level IR (HLIR)*.
- HLIRs are lowered into a universal MLIR.
- MLIR can be lowered into *low-level IR (LLIR)*, LLVM bitcode or C code.
- LLIR can be lowered to a native maschine instructions (x86_64, aarch64 and riscv).
- Alternatively LLIR can be executed directly by an interpreter.

<img width="621" height="1371" alt="architecture" src="https://github.com/user-attachments/assets/8bab2a18-1422-43e2-9cba-ba91930d780b" />

## Using ARCC

### Build and run
```sh
zig build
zig build run
zig build test
```

## Other

**Status**
- Work in progress. The pipeline is being assembled; details evolve.

**License**
- See `LICENSE`.

Created by Cedric Beck & Felix Koppe
