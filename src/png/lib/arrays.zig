const std = @import("std");

pub fn inSlice(haystack: [][]u8, needle: []u8) bool {
    for (haystack) |thing| {
        if (std.mem.eql(u8, thing, needle)) {
            return true;
        }
    }
    return false;
}