const std = @import("std");
const PNG_TYPES = @import("../types/png/png.zig");
const PIXEL_TYPE = @import("../types/pixels.zig");

pub fn get_square_average(gpa: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, grayscale_data: []PIXEL_TYPE.PixelStruct, split_num: u8) !std.ArrayList([]u32) {
    const WIDTH = png.IHDR.width;
    const HEIGHT = png.IHDR.height;

    const SPLIT_NUM: u8 = split_num;
    const SPLIT_WIDTH = @divTrunc(WIDTH, SPLIT_NUM);
    const SPLIT_HEIGHT = @divTrunc(HEIGHT, SPLIT_NUM);

    var GRAYSCALED_PIXELS = std.ArrayList([]u32).init(gpa.*);
    for (0..SPLIT_NUM) |main_height_index| {
        var GRAYSCALED_PIXELS_ROW = std.ArrayList(u32).init(gpa.*);
        for (0..SPLIT_NUM) |main_width_index| {
            var square_sum: u32 = 0;
            for (0..SPLIT_HEIGHT) |square_height_index| {
                for (0..SPLIT_WIDTH) |square_width_index| {
                    const PIXEL_INDEX = (square_width_index + square_height_index * WIDTH) + (main_width_index * SPLIT_WIDTH) + (main_height_index * SPLIT_HEIGHT * WIDTH);
                    const PIXEL = grayscale_data[PIXEL_INDEX];

                    var total_sum: u16 = PIXEL.R;
                    total_sum += PIXEL.G;
                    total_sum += PIXEL.B;
                    total_sum += PIXEL.A;

                    const average = @divTrunc(total_sum, 4);
                    square_sum += average;
                }
            }
            var square_sum_average: u32 = 0;
            if (square_sum > 0) {
                square_sum_average = @divTrunc(square_sum, SPLIT_HEIGHT * SPLIT_WIDTH);
            }

            var append: u32 = 0;
            if (square_sum_average != 255) {
                append = 1;
            }
            try GRAYSCALED_PIXELS_ROW.append(append);
        }

        try GRAYSCALED_PIXELS.append(GRAYSCALED_PIXELS_ROW.items);
    }

    return GRAYSCALED_PIXELS;
}
