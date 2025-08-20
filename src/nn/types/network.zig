const std = @import("std");
const TYPE_LAYER = @import("./layer.zig");


pub const Network = struct {
    input_layer: TYPE_LAYER.InputLayer,
    neural_layers: []TYPE_LAYER.Layer,
};