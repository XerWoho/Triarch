const std = @import("std");

pub const InputStruct = struct {
	activation: f32
};
pub const InputLayerStruct = struct {
    inputs: std.ArrayList(InputStruct),
};


pub const NeuronStruct = struct {
    activation: f32,
    bias: f32,
	connection_weights: std.ArrayList(f32),
	weights_velocity: std.ArrayList(f32),
    suggested_nudges: std.ArrayList(f32),
    delta: f32,
    bias_velocity: f32,
};

pub const LayerStruct = struct {
    neurons: std.ArrayList(NeuronStruct),
};
