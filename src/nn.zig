const std = @import("std");
const nn = @import("nn/brain.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try nn.brain(allocator);
}
