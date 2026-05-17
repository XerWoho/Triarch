const std = @import("std");

pub const Matrix = @This();

data: []f32,
in: usize, // node in
out: usize, // node out

pub fn init(
    allocator: std.mem.Allocator,
    in: usize,
    out: usize,
) !Matrix {
    const data = try allocator.alloc(f32, in * out);

    return .{
        .data = data,
        .in = in,
        .out = out,
    };
}

pub fn updateValueAt(self: *Matrix, in: usize, out: usize, value: f32) void {
    self.data[in * self.out + out] = value;
}

pub fn at(self: *Matrix, in: usize, out: usize) f32 {
    return self.data[in * self.out + out];
}

pub fn atPointer(self: *Matrix, in: usize, out: usize) *f32 {
    return &self.data[in * self.out + out];
}
