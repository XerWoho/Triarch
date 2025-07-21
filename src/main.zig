const std = @import("std");
const conversions = @import("lib/conversions.zig");
const huffman = @import("algorithms/huffman.zig");
const filter = @import("algorithms/filter.zig");
const lzss = @import("algorithms/lzss.zig");

const h = @import("lib/hex.zig");
const s = @import("lib/string.zig");
const c = @import("constants.zig");
const p = @import("types/png/png.zig");
const ancillary = @import("types/png/chunks/ancillary.zig");


pub fn main() !void {
    var png: p.PNGStruct = undefined;
    var gpa = std.heap.page_allocator;

    var file = try std.fs.cwd().openFile("test6.png", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
	var img_string = std.ArrayList(u8).init(gpa);
    defer img_string.deinit();
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try img_string.appendSlice(line);
        try img_string.appendSlice("\n");
    }

    const hex_dump = try h.hex_dump(&gpa, img_string.items, false);
    defer hex_dump.deinit();
    // var index: u64 = 0;
    // for(hex_dump.items) |dump| {
    //     std.debug.print("{s}", .{dump});
    //     index += 1;
    // }

	var hex_dumps = std.ArrayList(u8).init(gpa);
    for(hex_dump.items) |d| {
        try hex_dumps.appendSlice(d);
    }

    // verify PNG signature
    const formatted = try s.remove_whitespace(&gpa, hex_dumps.items);
    defer formatted.deinit();
    const formatted_string = formatted.items;


    const png_sig_slice = formatted_string[c.PNG_SIG_POSITION[0]..c.PNG_SIG_POSITION[1]];
    if (!std.mem.eql(u8, png_sig_slice, c.PNG_SIG)) {
        @panic("invalid PNG Header!");
    }


    // INIT IHDR
    // get PNG IHDR size
    const ihdr_size_slice = formatted_string[c.IHDR_SIZE_POSITION[0]..c.IHDR_SIZE_POSITION[1]];
    const ihdr_size = try conversions.hex_to_int(&gpa, ihdr_size_slice,u8);
    png.IHDR.size = ihdr_size;

    const ihdr_data = formatted_string[c.IHDR_START..c.IHDR_START + (ihdr_size * 2) + 8];
    const ihdr_png_width = ihdr_data[0..8];
    const ihdr_png_height = ihdr_data[8..16];
    const ihdr_png_bbp = ihdr_data[16..18];
    const ihdr_png_ct = ihdr_data[18..20];
    const ihdr_png_cm = ihdr_data[20..22];
    const ihdr_png_fm = ihdr_data[22..24];
    const ihdr_png_ii = ihdr_data[24..26];
    const ihdr_png_crc = ihdr_data[26..32];
    
    // define IHDR
    png.IHDR.width = try conversions.hex_to_int(&gpa, ihdr_png_width, u16);
    png.IHDR.height = try conversions.hex_to_int(&gpa, ihdr_png_height, u16);
    png.IHDR.bits_per_pixel = try conversions.hex_to_int(&gpa, ihdr_png_bbp, u8);
    png.IHDR.color_type = try conversions.hex_to_int(&gpa, ihdr_png_ct, u8);
    png.IHDR.compression_method = try conversions.hex_to_int(&gpa, ihdr_png_cm, u8);
    png.IHDR.filter_method = try conversions.hex_to_int(&gpa, ihdr_png_fm, u8);
    png.IHDR.interlaced = try  conversions.hex_to_int(&gpa, ihdr_png_ii, u8) == 1;
    png.IHDR.crc = try conversions.hex_to_int(&gpa, ihdr_png_crc, u16);



    // INIT ANCILLARY HEADERS
    var current_bit_position: u64 = c.IHDR_START + (ihdr_size * 2) + c.BYTE_LENGTH;
    while(!std.mem.eql(u8, "49444154", formatted_string[current_bit_position + c.BYTE_LENGTH..current_bit_position + c.BYTE_LENGTH * 2])) {
        const new_header_size_slice = formatted_string[current_bit_position..current_bit_position + c.BYTE_LENGTH];
        const new_header_size = try conversions.hex_to_int(&gpa, new_header_size_slice,u32);
        current_bit_position += c.BYTE_LENGTH * 3 + (new_header_size * 2);
    }



    // INIT IDAT
    // get PNG IDAT size
    const idat_size_slice = formatted_string[current_bit_position..current_bit_position + c.BYTE_LENGTH];
    current_bit_position += c.BYTE_LENGTH;
    const idat_size = try conversions.hex_to_int(&gpa, idat_size_slice,u32);
    png.IDAT.size = idat_size;

    const idat_header_slice = formatted_string[current_bit_position..current_bit_position + c.BYTE_LENGTH];
    current_bit_position += c.BYTE_LENGTH;
    if(!std.mem.eql(u8, idat_header_slice, "49444154")) {
        @panic("not correct IDAT header!");
    }

    const deflate_compression = formatted_string[current_bit_position..current_bit_position + c.BIT_LENGTH * 2];
    current_bit_position += c.BIT_LENGTH * 2;
    const zlib_fcheck_value = formatted_string[current_bit_position..current_bit_position + c.BIT_LENGTH * 2];
    current_bit_position += c.BIT_LENGTH * 2;

    // validate the zlib header
	const validation_value_hex = try std.fmt.allocPrint(gpa, "{s}{s}", .{deflate_compression, zlib_fcheck_value});
    const validation_value = try conversions.hex_to_int(&gpa, validation_value_hex, u16);
    if(validation_value % 31 != 0) {
        @panic("invalid zlib header!");
    }

    const compressed_data = formatted_string[current_bit_position..current_bit_position + (idat_size * 2) - 12];
    current_bit_position += (idat_size * 2) - 12; // - 12 => ZLIB header and CRC
    
    const zlib_checksum = formatted_string[current_bit_position..current_bit_position + c.BYTE_LENGTH];
    current_bit_position += c.BYTE_LENGTH;
    const idat_png_crc = formatted_string[current_bit_position..current_bit_position + c.BYTE_LENGTH];
    current_bit_position += c.BYTE_LENGTH;

    // define IDAT
    png.IDAT.compression_info = try conversions.hex_to_int(&gpa, deflate_compression[0..1], u16);
    png.IDAT.compression_method =  try conversions.hex_to_int(&gpa, deflate_compression[1..2], u8);
    png.IDAT.zlib_checksum = try conversions.hex_to_int(&gpa, zlib_checksum, u16);
    png.IDAT.zlib_fcheck_value = validation_value;
    png.IDAT.crc = try conversions.hex_to_int(&gpa, idat_png_crc, u16);
    png.IDAT.data = compressed_data;


    const binary_hex = try conversions.hex_to_binary(&gpa, png.IDAT.data, true);
    defer binary_hex.deinit();

    std.debug.print("{any}\n", .{png});
    try huffman.get_huffman_type(&gpa, binary_hex.items);
}
