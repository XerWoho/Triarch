const std = @import("std");
const Layer = @import("./layer.zig");

pub const NeuralNetwork = @This();

layers: []Layer,

pub fn create(layerSizes: []usize) !NeuralNetwork {
    const allocator = std.heap.page_allocator;
    var layers = try allocator.alloc(Layer, layerSizes.len - 1);
    for (0..layers.len) |i| {
        layers[i] = try Layer.create(layerSizes[i], layerSizes[i + 1]);
    }

    return .{
        .layers = layers,
    };
}

pub fn feedForward(self: *NeuralNetwork, inputs: []f32) !void {
    var _inputs = inputs;
    for (self.layers) |*layer| {
        _inputs = try layer.feedForward(_inputs);
    }
}

pub fn computeLoss(self: *NeuralNetwork, inputs: []f32, expected: []f32) !f32 {
    try self.feedForward(inputs);
    const output_layer = self.layers[self.layers.len - 1];
    var loss: f32 = 0;

    for (0..output_layer.activations.len) |nodeOut| {
        loss += Layer.mse(output_layer.activations[nodeOut], expected[nodeOut]);
    }

    return loss;
}

pub fn trainStep(self: *NeuralNetwork, inputs: []f32, expected: []f32, learnRate: f32) !void {
    try self.backpropagate(inputs, expected);
    try self.applyGradients(learnRate);
    try self.zeroGrad();
}

pub fn backpropagate(self: *NeuralNetwork, inputs: []f32, expected: []f32) !void {
    const previousLayer = self.layers[self.layers.len - 2];
    var output_layer = self.layers[self.layers.len - 1];
    var delta_values = try output_layer.computeOutputDeltas(expected);
    try output_layer.accumulateGradients(previousLayer.activations, delta_values);

    var last_hidden_layer_index = self.layers.len - 2;
    while(true) {
        var next_layer = self.layers[last_hidden_layer_index + 1];
        var hidden_layer = self.layers[last_hidden_layer_index];
        delta_values = try hidden_layer.computeHiddenDeltas(
            &next_layer,
            delta_values,
        );

        if(last_hidden_layer_index == 0) {
            try hidden_layer.accumulateGradients(inputs, delta_values);
            break;
        }

        try hidden_layer.accumulateGradients(self.layers[last_hidden_layer_index - 1].activations, delta_values);
        last_hidden_layer_index -= 1;
    }
}

pub fn applyGradients(self: *NeuralNetwork, learnRate: f32) !void {
    for (self.layers) |*layer| {
        try layer.applyGradients(learnRate);
    }
}

pub fn zeroGrad(self: *NeuralNetwork) !void {
    for (self.layers) |*layer| {
        try layer.clearGradients();
    }
}
