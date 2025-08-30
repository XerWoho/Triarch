const std = @import("std");

pub const InputStruct = struct {
	activation: f32
};
pub const InputLayerStruct = struct {
    inputs: []InputStruct,
};


pub const NeuronStruct = struct {
    activation: f32,
    bias: f32,
	connection_weights: []f32,
    delta: f32,
    suggested_nudges: std.ArrayList(f32)
};

pub const LayerStruct = struct {
    neurons: []NeuronStruct,
};
