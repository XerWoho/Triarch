// src/nn_main.zig
const std = @import("std");
const nn = @import("nn/brain.zig");

pub fn main() !void {
	try nn.brain();
}
