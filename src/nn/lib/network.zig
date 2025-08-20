const std = @import("std");
const LAYERS_INPUT = @import("../layers/input.zig");
const LAYERS_HIDDEN = @import("../layers/hidden.zig");
const LAYERS_OUTPUT = @import("../layers/output.zig");

const TYPES_LAYER = @import("../types/layer.zig");
const TYPES_NETWORK = @import("../types/network.zig");

pub fn create_network(allocator: *std.mem.Allocator, input_amount: u32, hidden_layers: []u32, output_amount: u32) !TYPES_NETWORK.Network {
	const input_layer = try LAYERS_INPUT.input_layer(allocator, input_amount);

	var neural_layers = std.ArrayList(TYPES_LAYER.Layer).init(allocator.*);
	for(0..hidden_layers.len) |i| {
		const hidden_amount = hidden_layers[i];
		var prev_size: u32 = 0;
		if(i == 0) {
			prev_size = input_amount;
		} else {
			prev_size = hidden_layers[i - 1];
		}
		const hidden_layer = try LAYERS_HIDDEN.hidden_layer(allocator, hidden_amount, @intCast(prev_size));
		try neural_layers.append(hidden_layer);
	}

	const prev_size: u32 = hidden_layers[hidden_layers.len - 1];
	const output_layers = try LAYERS_OUTPUT.output_layer(allocator, output_amount, @intCast(prev_size));
	try neural_layers.append(output_layers);

	const network = TYPES_NETWORK.Network{
		.input_layer = input_layer,
		.neural_layers = neural_layers.items,
	};

	return network;
}

pub fn set_input_activation(nn: *TYPES_NETWORK.Network, activation_inputs: []f32) !void {
	var input_layer = &nn.input_layer; // the very first layer

	for(0..activation_inputs.len) |i| {
		const activation = activation_inputs[i];
		input_layer.inputs[i].activation = activation; // set the activation value of the corresponding neuron
	}

	return;
}

