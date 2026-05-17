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
    const rand = std.crypto.random;
    return rand.float(f32) * 2.0 - 1.0;
}

fn xavierInit(in: usize, out: usize) f32 {
    const limit = @sqrt(6.0 / @as(f32, @floatFromInt(in + out)));
    const rand = std.crypto.random;
    return rand.float(f32) * 2.0 * limit - limit;
}

pub const Layer = @This();

weights: Matrix,
biases: []f32,

activations: []f32,
zValues: []f32,
deltaValues: []f32,

costGradientW: Matrix,
costGradientB: []f32,

numNodesIn: usize,
numNodesOut: usize,

pub fn create(numNodesIn: usize, numNodesOut: usize) !Layer {
    const allocator = std.heap.page_allocator;

    const costGradientB = try allocator.alloc(f32, numNodesOut);
    for (0..numNodesOut) |nO| {
        costGradientB[nO] = 0;
    }

    var costGradientW = try Matrix.init(allocator, numNodesIn, numNodesOut);
    for (0..numNodesIn) |nI| {
        for (0..numNodesOut) |nO| {
            costGradientW.updateValueAt(nI, nO, 0);
        }
    }

    const biases = try allocator.alloc(f32, numNodesOut);
    for (biases) |*b| {
        b.* = 0;
    }

    var weights = try Matrix.init(allocator, numNodesIn, numNodesOut);
    for (0..numNodesIn) |nI| {
        for (0..numNodesOut) |nO| {
            weights.updateValueAt(nI, nO, randomValue());
        }
    }

    const activations = try allocator.alloc(f32, numNodesOut);
    for (activations) |*a| {
        a.* = 0;
    }

    const zValues = try allocator.alloc(f32, numNodesOut);
    for (zValues) |*ra| {
        ra.* = 0;
    }

    const deltaValues = try allocator.alloc(f32, numNodesOut);
    for (deltaValues) |*n| {
        n.* = 0;
    }

    return .{
        .weights = weights,
        .biases = biases,

        .activations = activations,
        .zValues = zValues,
        .deltaValues = deltaValues,

        .costGradientW = costGradientW,
        .costGradientB = costGradientB,

        .numNodesIn = numNodesIn,
        .numNodesOut = numNodesOut,
    };
}

pub fn feedForward(self: *Layer, inputs: []f32) ![]f32 {
    for (0..self.numNodesOut) |nodeOut| {
        var activation = self.biases[nodeOut];
        for (0..self.numNodesIn) |nodeIn| {
            activation += inputs[nodeIn] * self.weights.at(nodeIn, nodeOut);
        }

        self.zValues[nodeOut] = activation;
        self.activations[nodeOut] = sigmoid(activation);
    }

    return self.activations;
}

pub fn computeOutputDeltas(self: *Layer, expected: []f32) ![]f32 {
    const allocator = std.heap.page_allocator;
    var deltaValues: []f32 = try allocator.alloc(f32, expected.len);
    for (0..deltaValues.len) |i| {
        const costDerivative = mseDerivative(self.activations[i], expected[i]);
        const activationDerivative = sigmoidDerivative(self.zValues[i]);
        deltaValues[i] = costDerivative * activationDerivative;
    }

    return deltaValues;
}

pub fn computeHiddenDeltas(self: *Layer, nextLayer: *Layer, nextDeltaValues: []f32) ![]f32 {
    const allocator = std.heap.page_allocator;

    var deltaValues: []f32 = try allocator.alloc(f32, self.numNodesOut);

    for (0..deltaValues.len) |deltaValueIndex| {
        var deltaValue: f32 = 0;
        for (0..nextDeltaValues.len) |nextDeltaValueIndex| {
            const weightedInputDerivative = nextLayer.weights.at(deltaValueIndex, nextDeltaValueIndex);
            deltaValue += weightedInputDerivative * nextDeltaValues[nextDeltaValueIndex];
        }

        deltaValue *= sigmoidDerivative(self.zValues[deltaValueIndex]);
        deltaValues[deltaValueIndex] = deltaValue;
    }

    return deltaValues;
}

pub fn accumulateGradients(self: *Layer, inputs: []f32, deltaValues: []f32) !void {
    for (0..self.numNodesOut) |nodeOut| {
        for (0..self.numNodesIn) |nodeIn| {
            const derivedCostWeight = inputs[nodeIn] * deltaValues[nodeOut];
            const cw = self.costGradientW.at(nodeIn, nodeOut);
            self.costGradientW.updateValueAt(nodeIn, nodeOut, cw + derivedCostWeight);
        }

        const derivedCostBias = 1 * deltaValues[nodeOut];
        self.costGradientB[nodeOut] += derivedCostBias;
    }
}

pub fn applyGradients(self: *Layer, learnRate: f32) !void {
    for (0..self.numNodesOut) |nodeOut| {
        self.biases[nodeOut] -= self.costGradientB[nodeOut] * learnRate;
        for (0..self.numNodesIn) |nodeIn| {
            const w = self.weights.at(nodeIn, nodeOut);
            const cw = self.costGradientW.at(nodeIn, nodeOut);
            self.weights.updateValueAt(nodeIn, nodeOut, w - cw * learnRate);
        }
    }
}

pub fn clearGradients(self: *Layer) !void {
    for (0..self.numNodesOut) |nodeOut| {
        self.costGradientB[nodeOut] = 0;
        for (0..self.numNodesIn) |nodeIn| {
            self.costGradientW.updateValueAt(nodeIn, nodeOut, 0);
        }
    }
}

pub fn mse(outputActivation: f32, expectedOutput: f32) f32 {
    const _error = outputActivation - expectedOutput;
    return _error * _error;
}

pub fn mseDerivative(outputActivation: f32, expectedOutput: f32) f32 {
    return 2 * (outputActivation - expectedOutput);
}
