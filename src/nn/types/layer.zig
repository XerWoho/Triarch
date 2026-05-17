const std = @import("std");
const Matrix = @import("matrix.zig");

fn sigmoid(x: f32) f32 {
    return 1.0 / (1.0 + @exp(-x));
}

fn sigmoidDerivative(x: f32) f32 {
    const activation = sigmoid(x);
    return activation * (1 - activation);
}

fn randomValue() f32 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var rand_implementation: std.Random.IoSource = .{ .io = io };
    var rand = rand_implementation.interface();

    return rand.float(f32) * 2.0 - 1.0;
}

fn xavierInit(in: usize, out: usize) f32 {
    const limit = @sqrt(6.0 / @as(f32, @floatFromInt(in + out)));
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var rand_implementation: std.Random.IoSource = .{ .io = io };
    var rand = rand_implementation.interface();
    
    return rand.float(f32) * 2.0 * limit - limit;
}

pub const Layer = @This();

weights: Matrix,
biases: []f32,

activations: []f32,
z_values: []f32,
delta_values: []f32,

cost_gradient_weights: Matrix,
cost_gradient_biases: []f32,

num_nodes_in: usize,
num_nodes_out: usize,

pub fn create(num_nodes_in: usize, num_nodes_out: usize) !Layer {
    const allocator = std.heap.page_allocator;

    const cost_gradient_biases = try allocator.alloc(f32, num_nodes_out);
    for (0..num_nodes_out) |nodes_out_index| {
        cost_gradient_biases[nodes_out_index] = 0;
    }

    var cost_gradient_weights = try Matrix.init(allocator, num_nodes_in, num_nodes_out);
    for (0..num_nodes_in) |nodes_in_index| {
        for (0..num_nodes_out) |nodes_out_index| {
            cost_gradient_weights.updateValueAt(nodes_in_index, nodes_out_index, 0);
        }
    }

    const biases = try allocator.alloc(f32, num_nodes_out);
    for (biases) |*b| {
        b.* = 0;
    }

    var weights = try Matrix.init(allocator, num_nodes_in, num_nodes_out);
    for (0..num_nodes_in) |nodes_in_index| {
        for (0..num_nodes_out) |nodes_out_index| {
            weights.updateValueAt(nodes_in_index, nodes_out_index, randomValue());
        }
    }

    const activations = try allocator.alloc(f32, num_nodes_out);
    for (activations) |*a| {
        a.* = 0;
    }

    const z_values = try allocator.alloc(f32, num_nodes_out);
    for (z_values) |*ra| {
        ra.* = 0;
    }

    const delta_values = try allocator.alloc(f32, num_nodes_out);
    for (delta_values) |*n| {
        n.* = 0;
    }

    return .{
        .weights = weights,
        .biases = biases,

        .activations = activations,
        .z_values = z_values,
        .delta_values = delta_values,

        .cost_gradient_weights = cost_gradient_weights,
        .cost_gradient_biases = cost_gradient_biases,

        .num_nodes_in = num_nodes_in,
        .num_nodes_out = num_nodes_out,
    };
}

pub fn feedForward(self: *Layer, inputs: []f32) ![]f32 {
    for (0..self.num_nodes_out) |nodeOut| {
        var activation = self.biases[nodeOut];
        for (0..self.num_nodes_in) |nodeIn| {
            activation += inputs[nodeIn] * self.weights.at(nodeIn, nodeOut);
        }

        self.z_values[nodeOut] = activation;
        self.activations[nodeOut] = sigmoid(activation);
    }

    return self.activations;
}

pub fn computeOutputDeltas(self: *Layer, expected: []f32) ![]f32 {
    const allocator = std.heap.page_allocator;
    var delta_values: []f32 = try allocator.alloc(f32, expected.len);
    for (0..delta_values.len) |i| {
        const cost_derivative = mseDerivative(self.activations[i], expected[i]);
        const activation_derivative = sigmoidDerivative(self.z_values[i]);
        delta_values[i] = cost_derivative * activation_derivative;
    }

    return delta_values;
}

pub fn computeHiddenDeltas(self: *Layer, next_layer: *Layer, next_delta_values: []f32) ![]f32 {
    const allocator = std.heap.page_allocator;

    var delta_values: []f32 = try allocator.alloc(f32, self.num_nodes_out);

    for (0..delta_values.len) |delta_value_index| {
        var delta_value: f32 = 0;
        for (0..next_delta_values.len) |next_delta_value_index| {
            const weighted_input_derivative = next_layer.weights.at(delta_value_index, next_delta_value_index);
            delta_value += weighted_input_derivative * next_delta_values[next_delta_value_index];
        }

        delta_value *= sigmoidDerivative(self.z_values[delta_value_index]);
        delta_values[delta_value_index] = delta_value;
    }

    return delta_values;
}

pub fn accumulateGradients(self: *Layer, inputs: []f32, delta_values: []f32) !void {
    for (0..self.num_nodes_out) |nodeOut| {
        for (0..self.num_nodes_in) |nodeIn| {
            const derived_cost_weight = inputs[nodeIn] * delta_values[nodeOut];
            const cw = self.cost_gradient_weights.at(nodeIn, nodeOut);
            self.cost_gradient_weights.updateValueAt(nodeIn, nodeOut, cw + derived_cost_weight);
        }

        const derivedCostBias = 1 * delta_values[nodeOut];
        self.cost_gradient_biases[nodeOut] += derivedCostBias;
    }
}

pub fn applyGradients(self: *Layer, learnRate: f32) !void {
    for (0..self.num_nodes_out) |nodeOut| {
        self.biases[nodeOut] -= self.cost_gradient_biases[nodeOut] * learnRate;
        for (0..self.num_nodes_in) |nodeIn| {
            const w = self.weights.at(nodeIn, nodeOut);
            const cw = self.cost_gradient_weights.at(nodeIn, nodeOut);
            self.weights.updateValueAt(nodeIn, nodeOut, w - cw * learnRate);
        }
    }
}

pub fn clearGradients(self: *Layer) !void {
    for (0..self.num_nodes_out) |nodeOut| {
        self.cost_gradient_biases[nodeOut] = 0;
        for (0..self.num_nodes_in) |nodeIn| {
            self.cost_gradient_weights.updateValueAt(nodeIn, nodeOut, 0);
        }
    }
}

pub fn mse(output_activation: f32, expected_output: f32) f32 {
    const _error = output_activation - expected_output;
    return _error * _error;
}

pub fn mseDerivative(output_activation: f32, expected_output: f32) f32 {
    return 2 * (output_activation - expected_output);
}
