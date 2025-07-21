const std = @import("std");
const c = @import("../constants.zig");

pub fn filter(width: u32, height: u32, bits_per_pixel: u8, color_type: u8) ![]u8 {
	const FILTER_TYPE = c.BYTE_LENGTH;
	const BYTES_PER_PIXEL = bits_per_pixel * 4 / 8;
	const ROW_LENGTH = FILTER_TYPE + (width * BYTES_PER_PIXEL);
	
}