const std = @import("std");
const PNG_TYPES = @import("../../png/types/png/png.zig");
const PIXEL_TYPE = @import("../../png/types/pixels.zig");

const CONSTANTS = @import("../constants.zig");

pub fn get_heatmap(
    gpa: *std.mem.Allocator, 
    png: *const PNG_TYPES.PNGStruct, 
    grayscale_data: []PIXEL_TYPE.PixelStruct, 

    invert: bool,
    split_w: u16,
    split_h: u16
) !std.ArrayList([]f32) {
    const WIDTH = png.IHDR.width;
    const HEIGHT = png.IHDR.height;
    const WIDTH_1P: u16 = @divTrunc(WIDTH, 10);
    const HEIGHT_1P: u16 = @divTrunc(HEIGHT, 10);

    const CONST_SPLIT_WIDTH = @divTrunc(WIDTH, split_w);
    const CONST_SPLIT_HEIGHT = @divTrunc(HEIGHT, split_h);
    
    var REMAINDER_WIDTH: u16 = WIDTH % split_w;
    if(REMAINDER_WIDTH < WIDTH_1P) REMAINDER_WIDTH = 0;
    var REMAINDER_HEIGHT: u16 = HEIGHT % split_h;
    if(REMAINDER_HEIGHT < HEIGHT_1P) REMAINDER_HEIGHT = 0;

    var HEATMAP = std.ArrayList([]f32).init(gpa.*);
    var main_height_index: u64 = 0;
    var main_width_index: u64 = 0;
    while (main_height_index < HEIGHT) {
        var HEATMAP_ROW = std.ArrayList(f32).init(gpa.*);
        var EXTRA_HEIGHT: u8 = 0;
        if(REMAINDER_HEIGHT > 0) {
            EXTRA_HEIGHT = 1;
            REMAINDER_HEIGHT -= 1;
        }

        const SPLIT_HEIGHT = CONST_SPLIT_HEIGHT + EXTRA_HEIGHT;
        while (main_width_index < WIDTH) {
            var EXTRA_WIDTH: u8 = 0;
            if(REMAINDER_WIDTH > 0) {
                EXTRA_WIDTH = 1;
                REMAINDER_WIDTH -= 1;
            }

            const SPLIT_WIDTH = CONST_SPLIT_WIDTH + EXTRA_WIDTH;
            var square_sum: u32 = 0;
            
            var square_height_index: u64 = 0;
            var square_width_index: u64 = 0;

            while (square_height_index < SPLIT_HEIGHT) {
                while (square_width_index < SPLIT_WIDTH) {
                    const PIXEL_WIDTH_OFFSET = main_width_index;
                    const PIXEL_HEIGHT_OFFSET = main_height_index * WIDTH;
                    const PIXEL_SQUARE_OFFSET = square_width_index + square_height_index * WIDTH;
                    const PIXEL_INDEX = PIXEL_SQUARE_OFFSET + PIXEL_WIDTH_OFFSET + PIXEL_HEIGHT_OFFSET;
                    if(grayscale_data.len <= PIXEL_INDEX) {
                        square_width_index += 1;
                        continue;
                    }
                    const PIXEL = grayscale_data[PIXEL_INDEX];

                    var total_sum: u16 = PIXEL.R;
                    total_sum += PIXEL.G;
                    total_sum += PIXEL.B;
                    // total_sum += PIXEL.A;

                    const average: i32 = @divTrunc(total_sum, 3);

                    if(invert) {
                        square_sum += @abs(average - CONSTANTS.RGB_WHITE); // invert the colors (255 -> 0 | 0 -> 255)
                    } else {
                        square_sum += @abs(average);
                    }
                    square_width_index += 1;
                }

                square_height_index += 1;
                square_width_index = 0;
            }

            var square_sum_average: u32 = 0;
            if (square_sum > 0) {
                square_sum_average = @divTrunc(square_sum, SPLIT_HEIGHT * SPLIT_WIDTH);
            }

            const square_sum_float: f32 = @floatFromInt(square_sum_average);
            const rgb_white_float: f32 = @floatFromInt(CONSTANTS.RGB_WHITE);
            try HEATMAP_ROW.append(square_sum_float / rgb_white_float);
            main_width_index += SPLIT_WIDTH;
        }

        try HEATMAP.append(HEATMAP_ROW.items);
        main_height_index += SPLIT_HEIGHT;
        main_width_index = 0;
    }


    return HEATMAP;
}
