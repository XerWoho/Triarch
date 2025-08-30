const std = @import("std");
const InputLayer = @import("../layers/input.zig");
const HiddenLayer = @import("../layers/hidden.zig");
const OutputLayer = @import("../layers/output.zig");

const LayerTypes = @import("../types/layer.zig");
const NetworkTypes = @import("../types/network.zig");

pub fn createNetwork(
	allocator: std.mem.Allocator, 
	input_amount: u32, 
	hidden_layers: []u32, 
	output_amount: u32,

	use_json: bool
) !NetworkTypes.NetworkStruct {
	const input_layer = try InputLayer.createInputLayer(allocator, input_amount);

	var neural_layers = std.ArrayList(LayerTypes.LayerStruct).init(allocator);
	var dumped_neurons: [][]NetworkTypes.DumpNeuronDataStruct = undefined;
	if(use_json) {
		const cwd = std.fs.cwd();
		file_valid: {
			const file_contents = cwd.readFileAlloc(allocator, "output.json", 4096 * 1000) catch {
				dumped_neurons = &[_][]NetworkTypes.DumpNeuronDataStruct{};
				break :file_valid;
			};

			defer allocator.free(file_contents);
			const parsed_dumped_nerons = try std.json.parseFromSlice(
				[][]NetworkTypes.DumpNeuronDataStruct,
				allocator,
				file_contents
			,
				.{},
			);
			dumped_neurons = parsed_dumped_nerons.value;
		}
	} else {
		dumped_neurons = &[_][]NetworkTypes.DumpNeuronDataStruct{};
	}

	for(0..hidden_layers.len) |i| {
		const hidden_amount = hidden_layers[i];
		var prev_size: u32 = 0;
		
		if(i == 0) prev_size = input_amount;
		if(i != 0) prev_size = hidden_layers[i - 1];

		if(dumped_neurons.len > i) {
			const hidden_layer = try HiddenLayer.createHiddenLayer(
				allocator, 
				hidden_amount, 
				@intCast(prev_size), 
				dumped_neurons[i]
			);
			try neural_layers.append(hidden_layer);
		} else {
			const hidden_layer = try HiddenLayer.createHiddenLayer(
				allocator, 
				hidden_amount, 
				@intCast(prev_size), 
				null
			);
			try neural_layers.append(hidden_layer);
		}
	}

	const prev_size: u32 = hidden_layers[hidden_layers.len - 1];

	if(dumped_neurons.len > hidden_layers.len) {
	const output_layers = try OutputLayer.output_layer(
		allocator, 
		output_amount, 
		@intCast(prev_size), 
		dumped_neurons[hidden_layers.len]
	);
	try neural_layers.append(output_layers);
	} else {
	const output_layers = try OutputLayer.output_layer(
		allocator, 
		output_amount, 
		@intCast(prev_size), 
		null
	);
	try neural_layers.append(output_layers);
	}


	const network = NetworkTypes.NetworkStruct{
		.input_layer = input_layer,
		.neural_layers = neural_layers.items,
	};

	return network;
}

pub fn setInputActivations(nn: *NetworkTypes.NetworkStruct, activation_inputs: []f32) !void {
	var input_layer = &nn.input_layer; // the very first layer

	for(0..activation_inputs.len) |i| {
		const activation = activation_inputs[i];
		input_layer.inputs[i].activation = activation; // set the activation value of the corresponding neuron
	}

	return;
}

