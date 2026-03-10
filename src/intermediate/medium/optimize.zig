const mlir = @import("./mlir.zig");

pub fn optimize(graph: *mlir.MLGraph) !void {
    var changed: bool = undefined;
    while (changed) {
        changed = false;
        changed |= try constantFold(graph);
        changed |= try simplifyAlgebra(graph);
        changed |= try simplifyCFG(graph);
        changed |= try deadCodeElim(graph);
    }
}

fn constantFold(graph: *mlir.MLGraph) !bool {
    _ = graph;
    return false;
}

fn simplifyAlgebra(graph: *mlir.MLGraph) !bool {
    _ = graph;

    return false;
}

fn simplifyCFG(graph: *mlir.MLGraph) !bool {
    _ = graph;

    return false;
}

fn deadCodeElim(graph: *mlir.MLGraph) !bool {
    _ = graph;
    return false;
}
