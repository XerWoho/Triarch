const std = @import("std");

pub const PixelStruct = struct {
    R: u8,
    G: u8,
    B: u8,
    A: u8,

    ROW_INDEX: u64,
    COLUMN_INDEX: u64,
};
