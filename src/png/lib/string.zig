const std = @import("std");

pub fn remove_whitespace(gpa: *std.mem.Allocator, bytes: []u8) !std.ArrayListAligned(u8, null) {
	var removed_whitespace = std.ArrayList(u8).init(gpa.*);

	for(bytes) |byte| {
		if(std.ascii.isWhitespace(byte)) continue;
		try removed_whitespace.append(byte);
	}

	return removed_whitespace;
}

pub fn reverse_string_no_alloc(bytes: []u8, out_buf: []u8) ![]u8 {
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

pub fn reverse_string(gpa: *std.mem.Allocator, bytes: []u8) !std.ArrayListAligned(u8, null) {
	var reversed_string = std.ArrayList(u8).init(gpa.*);

	var index = bytes.len;
	while(index > 0) {
		try reversed_string.append(bytes[index - 1]);
		index -= 1;
	}

	return reversed_string;
}