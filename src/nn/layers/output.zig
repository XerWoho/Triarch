const std = @import("std");

const LayerTypes = @import("../types/layer.zig");
const NetworkTypes = @import("../types/network.zig");

const Random = @import("../lib/random.zig");

pub fn output_layer(
	allocator: std.mem.Allocator, 
	size: u32, 
	prev_size: u32,
	dumped_neurons: ?[]NetworkTypes.DumpNeuronDataStruct
) !LayerTypes.LayerStruct {
	var output_layers = std.ArrayList(LayerTypes.NeuronStruct).init(allocator);

	for(0..size) |index| {
		var connection_weights = std.ArrayList(f32).init(allocator);
		for(0..prev_size) |w_index| {
			var w: f32 = Random.randomWeight();
			if(dumped_neurons != null) w = dumped_neurons.?[index].weights[w_index];

			connection_weights.append(w) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Appending failed.");
			};
		}


		var b: f32 = Random.randomBias();
		if(dumped_neurons != null) b = dumped_neurons.?[index].bias;
		const neuron = LayerTypes.NeuronStruct{
			.activation = 0,
			.bias = b,
			.connection_weights = connection_weights.items,
			.delta = 0,
			.suggested_nudges = std.ArrayList(f32).init(allocator)
		};
		output_layers.append(neuron) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Appending failed.");
		};
	}

	return LayerTypes.LayerStruct{
		.neurons = output_layers.items,
	};
}