const std = @import("std");
const llir = @import("./llir.zig");

pub fn reduce_variables(gpa: std.mem.Allocator, llmodule: *llir.LLModule) void {
    for (llmodule.funcs.items) |f| {
        const block_end = f.block_start + f.block_count;
        // var block_index = f.block_start;
        var block_index = block_end - 1;
        while (block_index >= f.block_start) : (block_index -= 1) {
            const block: llir.LLBock = llmodule.blocks.items[block_index];

            var value_set = std.AutoHashMap(llir.LLValueID, void).init(gpa);

            for (block.insts.items.len..0) |index| {
                const inst: llir.LLInst = block.insts.items[index];

                const uses = llmodule.instOperands(inst).slice();
                const def = llmodule.instResult(inst.id);


                //switch (inst.data) {
                //    .load => |x| uses.append(gpa, x.ptr),
                //    .store => |x| {
                //        def.append(gpa, x.ptr);
                //        uses.append(gpa, x.value);
                //    }, // write to memory
                //    //.gep => |x| {value_set.put(x.base_ptr); value_set.put(x.index);}, // pointer + scaled index
                //    .binary => |x| {
                //        def.append(gpa, x.lhs);
                //        uses.append(gpa, x.rhs);
                //    }, // integer arithmetic/bitwise op
                //    .icmp => {}, // integer comparison
                //    .cast => {}, // explicit type conversion
                //    .call => {}, // direct/indirect call
                //    .cond_br => {}, // conditional jump
                //    .ret => |x| {
                //        if (x.value) |val| {
                //            uses.append(gpa,val.value);
                //        }
                //    }, // function return
                //    else => {},
                //}

                for (uses) |x| {
                    if(value_set.contains(x)) value_set.remove(x);
                }

                for (def) |x| {
                    value_set.put(x);
                }
            }
        }
    }
}
