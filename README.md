# ARCC
Advanced Retargetable Compiler Collection


ARCC is a compiler collection that maps multiple frontends into a shared IR pipeline and targets multiple backends.

**Project goals**
- Provide a retargetable compiler pipeline with clear IR boundaries.
- Support multiple source languages via dedicated frontends.
- Enable multiple outputs and execution targets from a shared mid-level IR.

**Architecture overview**
- Inputs: TinyC, Simple C, and our own language.
- Pipeline: a central lexer feeds per-language parsers (handwritten or generated).
- Each frontend produces tokenstream, AST, then HLIR (high-level IR).
- HLIR merges into MLIR (mid-level IR).
- Outputs: LLVM bitcode, LLIR, C, and an interpreter; LLIR targets include x86_64 and aarch64.

<img width="741" height="1331" alt="ARCC block diagram" src="https://github.com/user-attachments/assets/315043ba-8c37-438f-b107-01c5c61b1aa9" />


**Build and run**
```sh
zig build
zig build run
zig build test
```

**Status**
- Work in progress. The pipeline is being assembled; details evolve.

**License**
- See `LICENSE`.

Created by Beck & Koppe
