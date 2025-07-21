const std = @import("std");

pub fn remove_whitespace(gpa: *std.mem.Allocator, bytes: []u8) !std.ArrayListAligned(u8, null) {
	var removed_whitespace = std.ArrayList(u8).init(gpa.*);

	for(bytes) |byte| {
		if(std.ascii.isWhitespace(byte)) continue;
		try removed_whitespace.append(byte);
	}

	return removed_whitespace;
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