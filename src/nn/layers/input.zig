const std = @import("std");
const TYPES_LAYER = @import("../types/layer.zig");

pub fn input_layer(allocator: *std.mem.Allocator, amount: u32) !TYPES_LAYER.InputLayer {
	var input_layers = std.ArrayList(TYPES_LAYER.Input).init(allocator.*);
	for(0..amount) |_| {
		const input = TYPES_LAYER.Input{
			.activation = 0,
		};
		try input_layers.append(input);
	}

	
	return TYPES_LAYER.InputLayer{
		.inputs = input_layers.items
	};
}