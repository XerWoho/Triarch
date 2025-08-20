
const std = @import("std");

const TYPES_NETWORK = @import("../types/network.zig");

const LIB_NUM_COMPRESSION = @import("./num_compression.zig");

const TN_RET = struct {
	index: u8,
	val: f32,
	cost: f32
};

pub fn test_network(nn: *TYPES_NETWORK.Network, target_num: u8, print: bool) !TN_RET {
	const allocator = std.heap.page_allocator;

	const neural_layers = nn.neural_layers;
	for(0.., neural_layers) |layer_index, layer| {
		const prev_layer_activations = try get_activations(allocator, nn, layer_index);
		defer prev_layer_activations.deinit();
		const neurons = layer.neurons;
		for(neurons) |*neuron| {
			const neuron_bias = neuron.bias;
			const connection_weights = neuron.connection_weights; // from previous layer
			var activation: f32 = 0;
			activation += neuron_bias;

			for(0.., connection_weights) |connection_weight_index, connection_weight| {
				activation += (connection_weight * prev_layer_activations.items[connection_weight_index]);
			}

			neuron.activation = LIB_NUM_COMPRESSION.sigmoid(activation);

		}
	}

	var expected_output = [_]f32{0,0,0,0,0,0,0,0,0,0};
	expected_output[target_num] = 1;

	var max: f32 = 0;
	var max_index: u8 = 0;
	for(0..10) |i| {
		const activation = nn.neural_layers[nn.neural_layers.len - 1].neurons[i].activation;
		if(max < activation) {
			max = activation;
			max_index = @intCast(i);
		}

		if(print) std.debug.print("{d} {d}\n", .{i, activation});
	}

	return TN_RET{
		.index = max_index,
		.val = max,
		.cost = try cost_function(nn, &expected_output)
	};
}


pub fn run_layers(nn: *TYPES_NETWORK.Network, target_num: u8) !f32 {
	const allocator = std.heap.page_allocator;

	const neural_layers = nn.neural_layers;
	const tn = try test_network(nn, target_num, false);

	var expected_output = [_]f32{0,0,0,0,0,0,0,0,0,0};
	expected_output[target_num] = 1;

	const derived_squared_residuals_relation_to_derived_predictions = try d_cost_function(nn, &expected_output);
	var i8_layer_index: i8 = @intCast(neural_layers.len - 1);
	const output_layer = neural_layers[@intCast(i8_layer_index)];
	const output_neurons = output_layer.neurons;
	for(0.., output_neurons) |j, *output_neuron| {
		const output_neuron_error = output_neuron.activation - expected_output[j];
    	output_neuron.delta = output_neuron_error * LIB_NUM_COMPRESSION.sigmoid_derivative(output_neuron.activation);
		
		var nudge: f32 = 0.0;	
		for(derived_squared_residuals_relation_to_derived_predictions) |derived_predictions| {
			nudge += (derived_predictions * output_neuron.delta);
		}
		try output_neuron.suggested_nudges.append(nudge);
	}
	i8_layer_index -= 1;

	while(i8_layer_index >= 0) : (i8_layer_index -= 1) {
		const layer_index: usize = @intCast(i8_layer_index);
		const layer = neural_layers[layer_index];
		const neurons = layer.neurons;
		for(0.., neurons) |neuron_index, *neuron| {
			_ = neuron_index;
			var i8_other_iterator: i8 = @intCast(neural_layers.len - 1);

			var delta: f32 = 0.0;
			while(i8_other_iterator >= i8_layer_index) : (i8_other_iterator -= 1) {
				const other_iterator: usize = @intCast(i8_other_iterator);
				const n_layer_activations = neural_layers[other_iterator];
				const n_layer_neurons = n_layer_activations.neurons;
				
				const n_prev_layer_activations = try get_activations(allocator, nn, other_iterator);
				defer n_prev_layer_activations.deinit();

				for(n_layer_neurons) |n_layer_neuron| {
					var nln_activation: f32 = 0;
					const n_layer_neuron_connection_weights = n_layer_neuron.connection_weights; // from previous layer
					for(0.., n_layer_neuron_connection_weights) |nln_connection_weight_index, nln_connection_weight| {
						nln_activation += (nln_connection_weight * LIB_NUM_COMPRESSION.sigmoid_derivative(n_prev_layer_activations.items[nln_connection_weight_index]));
					}
					delta += LIB_NUM_COMPRESSION.sigmoid_derivative(nln_activation) * neuron.delta;
				}
			}
			neuron.delta = delta;

			var nudge: f32 = 0.0;	
			
			for(derived_squared_residuals_relation_to_derived_predictions) |derived_predictions| {
				nudge += (derived_predictions * neuron.delta);
			}
			try neuron.suggested_nudges.append(nudge);
		}
	}

	return tn.cost;
}

pub fn set_nudges(nn: *TYPES_NETWORK.Network, learning_rate: f32) !void {
	const neural_layers = nn.neural_layers;

	var i8_layer_index: i8 = @intCast(neural_layers.len - 1);
	while(i8_layer_index >= 0) : (i8_layer_index -= 1) {
		const layer = neural_layers[@intCast(i8_layer_index)];
		const neurons = layer.neurons;
		for(neurons) |*neuron| {
			var nudge: f32 = 0.0;
			for(neuron.suggested_nudges.items) |sn| {
				nudge += sn;
			}

			const f_len: f32 = @floatFromInt(neuron.suggested_nudges.items.len);
			if(f_len > 0) {
				nudge = nudge / f_len;  // average nudge of all suggestions
			}

			neuron.bias += (nudge * learning_rate);
			const connection_weights = neuron.connection_weights; // previous layers connections to the neuron
			for(0.., connection_weights) |connection_index, *connection_weight| {
				if(i8_layer_index == 0) {
					const input_layer = nn.input_layer;
					const neuron_target = input_layer.inputs[connection_index];
					nudge *= neuron_target.activation;
				}
				connection_weight.* += (nudge * learning_rate);
			}

			neuron.suggested_nudges.clearRetainingCapacity();
		}
	}
}

fn get_activations(allocator: std.mem.Allocator, nn: *TYPES_NETWORK.Network, layer_index: usize) !std.ArrayList(f32) {
	const input_layer = nn.input_layer;
	const neural_layers = nn.neural_layers;

	var prev_layer_activations = std.ArrayList(f32).init(allocator);
	if(layer_index == 0) { // previous layer = input layer
		const previous_layer = input_layer;
		for(0..previous_layer.inputs.len) |input_index| {
			const a = previous_layer.inputs[input_index].activation;
			try prev_layer_activations.append(a);
		}
	} else {
		const previous_layer = neural_layers[layer_index - 1];
		for(0..previous_layer.neurons.len) |neuron_index| {
			const a = previous_layer.neurons[neuron_index].activation;
			try prev_layer_activations.append(a);
		}
	}

    return prev_layer_activations;
}

fn cost_function(nn: *TYPES_NETWORK.Network, expected_output: []f32) !f32 {
	var cost: f32 = 0;

	for(0..10) |i| {
		const activation = nn.neural_layers[nn.neural_layers.len - 1].neurons[i].activation;
		const expected = expected_output[i];

		const diff = (activation - expected);
		const diffsqr = diff * diff;
		cost += diffsqr; 
	}

	return cost;
}

fn d_cost_function(nn: *TYPES_NETWORK.Network, expected_output: []f32) ![10]f32 {
	var d_functions: [10]f32 = undefined;

	for(0..10) |i| {
		const activation = nn.neural_layers[nn.neural_layers.len - 1].neurons[i].activation;
		const expected = expected_output[i];

		const diff = -2 * (activation - expected);
		d_functions[i] = diff; 
	}

	return d_functions;
}