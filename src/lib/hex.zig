const std = @import("std");
const conversions = @import("../lib/conversions.zig");
const s = @import("../lib/string.zig");


const HEX_PRINT_AMOUNT = 2;
const HEX_SECTION_LENGTH = 8;
const HEX_BYTE_AMONUT = HEX_PRINT_AMOUNT * HEX_SECTION_LENGTH;

pub fn hex_flip_data(gpa: *std.mem.Allocator, bytes: []u8) !std.ArrayList(u8) {
	var flipped_hex = std.ArrayList(u8).init(gpa.*);

	var index: u32 = 0;
	while(index < bytes.len) {
		const str = bytes[index..index + 2];
		var flipped_str = try s.reverse_string(gpa, str);


		try flipped_hex.appendSlice(flipped_str.items);
		index += 2;
		defer flipped_str.deinit();
	}

	return flipped_hex;
}

pub fn hex_dump(gpa: *std.mem.Allocator, bytes: []u8, little: bool) !std.ArrayListAligned([]u8, null) {
    var dumped_data = std.ArrayList([]u8).init(gpa.*);

	var index: u32 = 0;
    while(index * HEX_BYTE_AMONUT < bytes.len) {
		var hex_dumped = std.ArrayList(u8).init(gpa.*);
		hex_dumped.deinit();
        var print_index: u8 = 0;
        for ([_]u0{0} ** HEX_SECTION_LENGTH) |_| {
            if(index * HEX_BYTE_AMONUT + print_index + HEX_PRINT_AMOUNT > bytes.len) break;
            const hex_to = try hex_multiple(bytes[index * HEX_BYTE_AMONUT + print_index..index * HEX_BYTE_AMONUT + (HEX_PRINT_AMOUNT + print_index)], little);
            defer hex_to.deinit();

			try hex_dumped.appendSlice(hex_to.items);
            try hex_dumped.appendSlice(" ");
            print_index += HEX_PRINT_AMOUNT;
        }
		try hex_dumped.appendSlice("\n");
		try dumped_data.append(hex_dumped.items);
        index += 1;
    }

	return dumped_data;
}

pub fn hex_multiple(bytes: []u8, little: bool) !std.ArrayListAligned(u8, null) {
    var gpa = std.heap.page_allocator;
	var return_string = std.ArrayList(u8).init(gpa);
	for(bytes) |byte| {
		const next_character = try conversions.int_to_hex(&gpa, byte);
		defer next_character.deinit();
		if(little) {
			try return_string.insertSlice(0, next_character.items); // lil-endian
		} else {
			try return_string.appendSlice(next_character.items);
		}
	}

	return return_string;
}

