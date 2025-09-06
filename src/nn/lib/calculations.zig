
const std = @import("std");

const NetworkTypes = @import("../types/network.zig");
const LayerTypes = @import("../types/layer.zig");

const NumCompression = @import("./num_compression.zig");
const Constants = @import("../constants.zig");

const TestNetworkStruct = struct {
	index: u8,
	val: f32,
	cost: f32
};

pub fn testNetwork(nn: *NetworkTypes.NetworkStruct, expected_output: []f32, print: bool) !TestNetworkStruct {
	try forwardPassing(nn);

	var max: f32 = 0;
	var max_index: u8 = 0;
	for(0..expected_output.len) |i| {
		const activation = nn.neural_layers[nn.neural_layers.len - 1].neurons.items[i].activation;
		if(max < activation) {
			max = activation;
			max_index = @intCast(i);
		}

		if(print) std.debug.print("{d} {d}\n", .{i, activation});
	}

	return TestNetworkStruct{
		.index = max_index,
		.val = max,
		.cost = try costFunction(nn, expected_output)
	};
}


pub fn runLayers(nn: *NetworkTypes.NetworkStruct, expected_output: []f32) !TestNetworkStruct {
	const test_network = try testNetwork(nn, expected_output, false);
	try backPropagation(nn, expected_output);

	return test_network;
}

pub fn setNudges(nn: *NetworkTypes.NetworkStruct, learning_rate: f32) !void {
	const allocator = std.heap.page_allocator;
	const neural_layers = nn.neural_layers;

	var i8_layer_index: i8 = @intCast(neural_layers.len - 1);
	while(i8_layer_index >= 0) : (i8_layer_index -= 1) {
		const layer = neural_layers[@intCast(i8_layer_index)];
		const neurons = layer.neurons.items;
		for(neurons) |*neuron| {
			var nudge: f32 = 0.0;
			for(neuron.suggested_nudges.items) |sn| {
				nudge += sn;
			}
			const f_len: f32 = @floatFromInt(neuron.suggested_nudges.items.len);
			if(f_len > 0) {
				nudge = nudge / f_len;  // average nudge of all suggestions
			}

			const bias_gradient = nudge * learning_rate;
			const old_nudge = nudge;
			const weight_gradients = try allocator.alloc(f32, neuron.connection_weights.items.len);
			for(0..neuron.connection_weights.items.len) |connection_index| {
				const previous_neuron_activation = switch (i8_layer_index) {
					0 => nn.input_layer.inputs.items[connection_index].activation,
					else => nn.neural_layers[@intCast(i8_layer_index - 1)].neurons.items[connection_index].activation
				};
				nudge = old_nudge * previous_neuron_activation;
				weight_gradients[connection_index] = nudge * learning_rate;
			}

			try gradientDescent(neuron, bias_gradient, weight_gradients);
			
			// free up memory space
			allocator.free(weight_gradients);
			neuron.suggested_nudges.clearRetainingCapacity();
		}
	}
}

fn gradientDescent(neuron: *LayerTypes.NeuronStruct, b_gardient: f32, w_gradient: []f32) !void {
	neuron.bias_velocity = Constants.MOMENTUM * neuron.bias_velocity + b_gardient;
	neuron.bias -= neuron.bias_velocity;

	const weights = neuron.connection_weights.items; // previous layers connections to the neuron
	const velocity = neuron.weights_velocity.items; // previous layers connections to the neuron
	for(weights, velocity, 0..) |*w, *v, i| {
    	v.* = Constants.MOMENTUM * v.* + w_gradient[i];
		w.* -= v.*;
	}
}

fn getActivations(allocator: std.mem.Allocator, nn: *NetworkTypes.NetworkStruct, layer_index: usize) !std.ArrayList(f32) {
	const input_layer = nn.input_layer;
	const neural_layers = nn.neural_layers;

	var prev_layer_activations = std.ArrayList(f32).init(allocator);
	if(layer_index == 0) { // previous layer = input layer
		const previous_layer = input_layer;
		for(0..previous_layer.inputs.items.len) |input_index| {
			const a = previous_layer.inputs.items[input_index].activation;
			prev_layer_activations.append(a) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Appending failed.");
			};
		}
	} else {
		const previous_layer = neural_layers[layer_index - 1];
		for(0..previous_layer.neurons.items.len) |neuron_index| {
			const a = previous_layer.neurons.items[neuron_index].activation;
			prev_layer_activations.append(a) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Appending failed.");
			};
		}
	}

    return prev_layer_activations;
}

fn forwardPassing(nn: *NetworkTypes.NetworkStruct) !void {
	const allocator = std.heap.page_allocator;

	const neural_layers = nn.neural_layers;
	for(0.., neural_layers) |layer_index, layer| {
		const prev_layer_activations = try getActivations(allocator, nn, layer_index);
		defer prev_layer_activations.deinit();
		const neurons = layer.neurons.items;
		for(neurons) |*neuron| {
			const neuron_bias = neuron.bias;
			const connection_weights = neuron.connection_weights.items; // from previous layer
			var activation: f32 = 0;
			activation += neuron_bias;

			for(0.., connection_weights) |connection_weight_index, connection_weight| {
				activation += (connection_weight * prev_layer_activations.items[connection_weight_index]);
			}

			if(layer_index == nn.neural_layers.len - 1) { // the output layer
				neuron.activation = NumCompression.outputActivation(activation);
			} else { // hidden layer
				neuron.activation = NumCompression.hiddenActivation(activation);
			}
		}
	}
}

fn backPropagation(nn: *NetworkTypes.NetworkStruct, expected_output: []f32) !void {
	const allocator = std.heap.page_allocator;
	const neural_layers = nn.neural_layers;

	var i8_layer_index: i8 = @intCast(neural_layers.len - 1);
	const output_layer = neural_layers[@intCast(i8_layer_index)];
	const output_neurons = output_layer.neurons.items;
	for(0.., output_neurons) |output_neuron_index, *output_neuron| {
		var activation_value_output: f32 = 0.0;
		for(0.., neural_layers[@intCast(i8_layer_index - 1)].neurons.items) |neuron_index, neuron| {
			const neuron_activation = neuron.activation;
			const neuron_weight = output_neuron.connection_weights.items[neuron_index];
			activation_value_output += neuron_weight * neuron_activation;
		}
    	output_neuron.delta = singleDerivedCost(
			output_neuron.activation, 
			expected_output[output_neuron_index]) * NumCompression.outputDerivedActivation(activation_value_output);
		const nudge: f32 = output_neuron.delta; 	

		output_neuron.suggested_nudges.append(nudge) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Appending failed.");
		};
	}
	i8_layer_index -= 1;

	while(i8_layer_index >= 0) : (i8_layer_index -= 1) {
		const layer_index: usize = @intCast(i8_layer_index);
		const layer = neural_layers[layer_index];
		const neurons = layer.neurons.items;
		for(0.., neurons) |neuron_index, *neuron| {
			var activation_value_neuron: f32 = 0.0;
			if(i8_layer_index > 0) {
				for(0.., neural_layers[@intCast(i8_layer_index - 1)].neurons.items) |prev_neuron_index, prev_neuron| {
					const neuron_activation = prev_neuron.activation;
					const neuron_weight = neuron.connection_weights.items[prev_neuron_index];
					activation_value_neuron += neuron_weight * neuron_activation;
				}
			} else {
				for(0.., nn.input_layer.inputs.items) |prev_neuron_index, prev_neuron| {
					const neuron_activation = prev_neuron.activation;
					const neuron_weight = neuron.connection_weights.items[prev_neuron_index];
					activation_value_neuron += neuron_weight * neuron_activation;
				}	
			}

			var delta: f32 = 0.0;
			var i8_previous_layer_iterator: i8 = @intCast(neural_layers.len - 1);
			while(i8_previous_layer_iterator >= i8_layer_index) : (i8_previous_layer_iterator -= 1) {
				const n_layer_index: usize = @intCast(i8_previous_layer_iterator);
				const n_layer_activations = neural_layers[n_layer_index];
				const n_layer_neurons = n_layer_activations.neurons.items;
				
				const n_prev_layer_activations = try getActivations(allocator, nn, n_layer_index);
				defer n_prev_layer_activations.deinit();
				var neuron_delta: f32 = 0;
				for(n_layer_neurons) |n_layer_neuron| {
					neuron_delta += n_layer_neuron.delta * n_layer_neuron.connection_weights.items[neuron_index];
				}
				
				const f32_len: f32 = @floatFromInt(n_layer_neurons.len);
				delta += neuron_delta / f32_len;
			}
			neuron.delta = delta * NumCompression.hiddenDerivedActivation(activation_value_neuron);
			const nudge: f32 = neuron.delta;
			neuron.suggested_nudges.append(nudge) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Appending failed.");
			};
		}
	}
}

fn singleCost(activation: f32, expected: f32) f32 {
	if(expected == 0) {
		return -1.0 * @log(1 - activation);
	}
	return -1.0 * @log(activation);
    // avoid log(0) by clamping
    // const eps: f32 = 1e-7;
    // const a = if (activation < eps) eps else if (activation > 1.0 - eps) 1.0 - eps else activation;

    // return -1.0 * (expected * @log(a) + (1.0 - expected) * @log(1.0 - a));
}

fn costFunction(nn: *NetworkTypes.NetworkStruct, expected_output: []f32) !f32 {
	var cost: f32 = 0;

	for(0..expected_output.len) |i| {
		const activation = nn.neural_layers[nn.neural_layers.len - 1].neurons.items[i].activation;
		const expected = expected_output[i];
		cost += singleCost(activation, expected); 
	}

	return cost;
}


fn singleDerivedCost(activation: f32, expected: f32) f32 {
	const err = activation - expected;
	return err;
}


fn derivedCostFunction(nn: *NetworkTypes.NetworkStruct, expected_output: []f32) ![]f32 {
	var allocator = std.heap.page_allocator;
	var d_functions: []f32 = try allocator.alloc(f32, expected_output.len);

	for(0..expected_output.len) |i| {
		const activation = nn.neural_layers[nn.neural_layers.len - 1].neurons.items[i].activation;
		const expected = expected_output[i];
		const diff = singleDerivedCost(activation, expected);

		d_functions[i] = diff; 
	}

	return d_functions;
}