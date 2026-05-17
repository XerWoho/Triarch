// src/nn_main.zig
const std = @import("std");
const nn = @import("nn/brain.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    nn.brain(allocator) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Brain initializing went wrong!");
    };
}
