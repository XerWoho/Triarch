const std = @import("std");
const critical = @import("chunks/critial.zig");

pub const PNGStruct = struct {
    PLTE: critical.PLTEStruct,
    IHDR: critical.IHDRStruct,
    IDAT: critical.IDATStruct,
};
