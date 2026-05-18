const std = @import("std");

pub fn removeWhitespace(allocator: std.mem.Allocator, bytes: []u8) !std.ArrayList(u8) {
	var removed_whitespace = try std.ArrayList(u8).initCapacity(allocator, 30);

	for(bytes) |byte| {
		if(std.ascii.isWhitespace(byte)) continue;
		try removed_whitespace.append(allocator, byte);
	}

	return removed_whitespace;
}

pub fn reverseStringNoAlloc(bytes: []u8, out_buf: []u8) ![]u8 {
    if (out_buf.len < bytes.len) return error.BufferTooSmall;

    var index = bytes.len;
    var out_index: usize = 0;
    while (index > 0) {
        out_buf[out_index] = bytes[index - 1];
        out_index += 1;
        index -= 1;
    }
	
    return out_buf[0..bytes.len];
}

pub fn reverseString(allocator: std.mem.Allocator, bytes: []u8) !std.ArrayListAligned(u8, null) {
	var reversed_string = try std.ArrayList(u8).initCapacity(allocator, 30);

	var index = bytes.len;
	while(index > 0) {
		try reversed_string.append(allocator, bytes[index - 1]);
		index -= 1;
	}

	return reversed_string;
}