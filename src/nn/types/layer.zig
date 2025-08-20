const std = @import("std");

pub const Input = struct {
	activation: f32
};
pub const InputLayer = struct {
    inputs: []Input,
};


pub const Neuron = struct {
    activation: f32,
    bias: f32,
	connection_weights: []f32,
    delta: f32,
    suggested_nudges: std.ArrayList(f32)
};

pub const Layer = struct {
    neurons: []Neuron,
};
