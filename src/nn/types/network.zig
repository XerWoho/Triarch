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
    const outputLayer = self.layers[self.layers.len - 1];
    var loss: f32 = 0;

    for (0..outputLayer.activations.len) |nodeOut| {
        loss += Layer.mse(outputLayer.activations[nodeOut], expected[nodeOut]);
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
    var outputLayer = self.layers[self.layers.len - 1];
    var deltaValues = try outputLayer.computeOutputDeltas(expected);
    try outputLayer.accumulateGradients(previousLayer.activations, deltaValues);

    var lastHiddenlayerIndex = self.layers.len - 2;
    while(true) {
        var nextLayer = self.layers[lastHiddenlayerIndex + 1];
        var hiddenLayer = self.layers[lastHiddenlayerIndex];
        deltaValues = try hiddenLayer.computeHiddenDeltas(
            &nextLayer,
            deltaValues,
        );

        if(lastHiddenlayerIndex == 0) {
            try hiddenLayer.accumulateGradients(inputs, deltaValues);
            break;
        } 

        try hiddenLayer.accumulateGradients(self.layers[lastHiddenlayerIndex - 1].activations, deltaValues);
        lastHiddenlayerIndex -= 1;
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
