const std = @import("std");

const TYPES_LAYER = @import("../types/layer.zig");

const RANDOM = @import("../lib/random.zig");

pub fn output_layer(allocator: *std.mem.Allocator, size: u32, prev_size: u32) !TYPES_LAYER.Layer {
	var output_layers = std.ArrayList(TYPES_LAYER.Neuron).init(allocator.*);

	for(0..size) |_| {
		var connection_weights = std.ArrayList(f32).init(allocator.*);
		for(0..prev_size) |_| {
			try connection_weights.append(RANDOM.random_weight());
		}

		const neuron = TYPES_LAYER.Neuron{
			.activation = 0,
			.bias = RANDOM.random_bias(),
			.connection_weights = connection_weights.items,
			.delta = 0,
			.suggested_nudges = std.ArrayList(f32).init(allocator.*)
		};
		try output_layers.append(neuron);
	}

	return TYPES_LAYER.Layer{
		.neurons = output_layers.items,
	};
}