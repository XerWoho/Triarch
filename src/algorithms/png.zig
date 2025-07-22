const std = @import("std");
const PNG_TYPES = @import("../types/png/png.zig");

const LIB_HEX = @import("../lib/hex.zig");
const LIB_STRING = @import("../lib/string.zig");
const LIB_CONSTANTS = @import("../lib/constants.zig");
const LIB_CONVERSIONS = @import("../lib/conversions.zig");

pub fn get_png(allocator: *std.mem.Allocator, binary: []u8) !PNG_TYPES.PNGStruct {
    var current_bit_position: u32 = 0;
    var png: PNG_TYPES.PNGStruct = undefined;

    const png_sig_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH * 2;

    // verify PNG signature
    if (!std.mem.eql(u8, png_sig_slice, LIB_CONSTANTS.PNG_SIG)) {
        @panic("invalid PNG Header!");
    }

    try get_ihdr(allocator, &png, binary, &current_bit_position);
    try get_plte(allocator, &png, binary, &current_bit_position);
    try get_ancillary(allocator, &png, binary, &current_bit_position);
    try get_idat(allocator, &png, binary, &current_bit_position);

    return png;
}

pub fn get_ihdr(allocator: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;

    // INIT IHDR
    // get PNG IHDR size
    const ihdr_size_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
    const ihdr_size = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_size_slice, u8);
    png.IHDR.size = ihdr_size;

    const ihdr_header_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
    if (!std.mem.eql(u8, ihdr_header_slice, LIB_CONSTANTS.IHDR_SIG)) {
        @panic("not correct IHDR header!");
    }

    const ihdr_png_width = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
    const ihdr_png_height = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
    const ihdr_png_bbp = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_ct = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_cm = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_fm = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_ii = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_crc = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;

    // define IHDR
    png.IHDR.width = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_width, u16);
    png.IHDR.height = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_height, u16);
    png.IHDR.bits_per_pixel = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_bbp, u8);
    png.IHDR.color_type = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_ct, u8);
    png.IHDR.compression_method = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_cm, u8);
    png.IHDR.filter_method = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_fm, u8);
    png.IHDR.interlaced = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_ii, u8) == 1;
    png.IHDR.crc = ihdr_png_crc;

    cbp.* = current_bit_position;
}

pub fn get_plte(allocator: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;

    // INIT PLTE
    plte_chunk: {
        if (png.IHDR.color_type == 0 or png.IHDR.color_type == 4) {
            png.PLTE.size = 0;
            png.PLTE.crc = &[_]u8{};

            png.PLTE.red = 0;
            png.PLTE.green = 0;
            png.PLTE.blue = 0;
            break :plte_chunk;
        }

        const plte_size_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
        current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
        const plte_size = try LIB_CONVERSIONS.hex_to_int(allocator, plte_size_slice, u32);
        png.PLTE.size = plte_size;

        const plte_header = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
        current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
        if (!std.mem.eql(u8, plte_header, LIB_CONSTANTS.PLTE_SIG)) {
            current_bit_position -= LIB_CONSTANTS.BYTE_LENGTH * 2;
            break :plte_chunk;
        }

        if (plte_size % 3 != 0) {
            @panic("invalid PLTE chunk size!");
        }

        const red_palette_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
        const green_palette_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
        const blue_palette_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];

        const red_palette = try LIB_CONVERSIONS.hex_to_int(allocator, red_palette_slice, u8);
        const green_palette = try LIB_CONVERSIONS.hex_to_int(allocator, green_palette_slice, u8);
        const blue_palette = try LIB_CONVERSIONS.hex_to_int(allocator, blue_palette_slice, u8);

        png.PLTE.red = red_palette;
        png.PLTE.green = green_palette;
        png.PLTE.blue = blue_palette;

        const plte_png_crc = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
        current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;

        png.PLTE.crc = plte_png_crc;
    }

    cbp.* = current_bit_position;
}

pub fn get_ancillary(allocator: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;
    _ = png;

    // INIT ANCILLARY CHUNKS
    while (!std.mem.eql(u8, LIB_CONSTANTS.IDAT_SIG, binary[current_bit_position + LIB_CONSTANTS.BYTE_LENGTH .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH * 2])) {
        const new_header_size_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
        const new_header_size = try LIB_CONVERSIONS.hex_to_int(allocator, new_header_size_slice, u32);
        current_bit_position += LIB_CONSTANTS.BYTE_LENGTH * 3 + (new_header_size * 2);
    }

    cbp.* = current_bit_position;
}

pub fn get_idat(allocator: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;

    // INIT IDAT
    // get PNG IDAT size
    const idat_size_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
    const idat_size = try LIB_CONVERSIONS.hex_to_int(allocator, idat_size_slice, u32);
    png.IDAT.size = idat_size;

    const idat_header_slice = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
    if (!std.mem.eql(u8, idat_header_slice, LIB_CONSTANTS.IDAT_SIG)) {
        @panic("not correct IDAT header!");
    }

    const deflate_compression = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;
    const zlib_fcheck_value = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;

    // validate the zlib header
    const validation_value_hex = try std.fmt.allocPrint(allocator.*, "{s}{s}", .{ deflate_compression, zlib_fcheck_value });
    const validation_value = try LIB_CONVERSIONS.hex_to_int(allocator, validation_value_hex, u16);
    if (validation_value % 31 != 0) {
        @panic("invalid zlib header!");
    }

    const compressed_data = binary[current_bit_position .. current_bit_position + (idat_size * 2) - 12];
    current_bit_position += (idat_size * 2) - 12; // - 12 => ZLIB header and CRC

    const zlib_checksum = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;
    const idat_png_crc = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH;

    // define IDAT
    png.IDAT.compression_info = try LIB_CONVERSIONS.hex_to_int(allocator, deflate_compression[0..1], u16);
    png.IDAT.compression_method = try LIB_CONVERSIONS.hex_to_int(allocator, deflate_compression[1..2], u8);
    png.IDAT.zlib_checksum = try LIB_CONVERSIONS.hex_to_int(allocator, zlib_checksum, u16);
    png.IDAT.zlib_fcheck_value = validation_value;
    png.IDAT.crc = idat_png_crc;
    png.IDAT.data = compressed_data;

    cbp.* = current_bit_position;
}
