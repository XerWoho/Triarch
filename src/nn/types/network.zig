const std = @import("std");
const LayerTypes = @import("./layer.zig");


pub const NetworkStruct = struct {
    input_layer: LayerTypes.InputLayerStruct,
    neural_layers: []LayerTypes.LayerStruct,
};



pub const DumpNeuronDataStruct = struct {
	bias: f32,
	weights: []f32,
	neuron_index: u32,
	layer_index: u32,
};