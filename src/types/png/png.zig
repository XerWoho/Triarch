const std = @import("std");
const critical = @import("chunks/critial.zig");

pub const PNGStruct = struct {
    PLTE: critical.PLTEStruct,
    IHDR: critical.IHDRStruct,
    IDAT: []critical.IDATStruct,
};

pub const RGBStruct = struct {
    R: u8,
    G: u8,
    B: u8,
};
