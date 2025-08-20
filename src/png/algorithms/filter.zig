const std = @import("std");
const PNG_TYPES = @import("../types/png/png.zig");
const PIXEL_TYPE = @import("../types/pixels.zig");

pub fn get_filter(gpa: *std.mem.Allocator, uncompressed_data: std.ArrayList(u8), png: *PNG_TYPES.PNGStruct) !std.ArrayList(PIXEL_TYPE.PixelStruct) {
    const IMAGE_WIDTH = png.IHDR.width;
    const IMAGE_HEIGHT = png.IHDR.height;

    return switch (png.IHDR.color_type) {
        0 => try get_filter_grayscale(gpa, uncompressed_data.items, IMAGE_HEIGHT, (1 + (IMAGE_WIDTH * 1))),
        2 => return try get_filter_rgb(gpa, uncompressed_data.items, IMAGE_HEIGHT, (1 + (IMAGE_WIDTH * 3))),
        4 => return try get_filter_grayscale_a(gpa, uncompressed_data.items, IMAGE_HEIGHT, (1 + (IMAGE_WIDTH * 2))),
        6 => return try get_filter_rgba(gpa, uncompressed_data.items, IMAGE_HEIGHT, (1 + (IMAGE_WIDTH * 4))),
        else => @panic("invalid type"),
    };
}

pub fn get_filter_rgba(gpa: *std.mem.Allocator, uncompressed_data: []u8, IMAGE_HEIGHT: u64, ROW_SIZE: u64) !std.ArrayList(PIXEL_TYPE.PixelStruct) {
    var PIXELS_WRAPPER = std.ArrayList(PIXEL_TYPE.PixelStruct).init(gpa.*);
    const UNCOMPRESSED = uncompressed_data;

    var CURRENT_FILTER_METHOD: u8 = 0;
    var HEIGHT_INDEX: u64 = 0;
    for (0..IMAGE_HEIGHT) |_| {
        var ROW_INDEX: u64 = 0;
        while (true) {
            const BIT_INDEX = HEIGHT_INDEX * ROW_SIZE + ROW_INDEX;

            if (BIT_INDEX >= ROW_SIZE * (HEIGHT_INDEX + 1)) break;
            if (BIT_INDEX >= UNCOMPRESSED.len) break;
            if (ROW_INDEX == 0) {
                CURRENT_FILTER_METHOD = UNCOMPRESSED[BIT_INDEX];
                ROW_INDEX += 1;
                continue;
            }

            if (CURRENT_FILTER_METHOD == 0) { // NO FILTER
                const RBIT = UNCOMPRESSED[BIT_INDEX];
                const GBIT = UNCOMPRESSED[BIT_INDEX + 1];
                const BBIT = UNCOMPRESSED[BIT_INDEX + 2];
                const ABIT = UNCOMPRESSED[BIT_INDEX + 3];

                const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = RBIT, .G = GBIT, .B = BBIT, .A = ABIT, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

                try PIXELS_WRAPPER.append(CURRENT_PIXEL);
                ROW_INDEX += 4;
                continue;
            }

            var u16_RBIT: u16 = UNCOMPRESSED[BIT_INDEX];
            var u16_GBIT: u16 = UNCOMPRESSED[BIT_INDEX + 1];
            var u16_BBIT: u16 = UNCOMPRESSED[BIT_INDEX + 2];
            var u16_ABIT: u16 = UNCOMPRESSED[BIT_INDEX + 3];

            if (CURRENT_FILTER_METHOD == 1) {
                var PreviousRBIT: u16 = 0;
                var PreviousGBIT: u16 = 0;
                var PreviousBBIT: u16 = 0;
                var PreviousABIT: u16 = 0;

                if (ROW_INDEX >= 4) {
                    PreviousRBIT = UNCOMPRESSED[BIT_INDEX - 4];
                    PreviousGBIT = UNCOMPRESSED[BIT_INDEX - 3];
                    PreviousBBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousABIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                u16_RBIT = @intCast(@mod(u16_RBIT + PreviousRBIT, 256));
                u16_GBIT = @intCast(@mod(u16_GBIT + PreviousGBIT, 256));
                u16_BBIT = @intCast(@mod(u16_BBIT + PreviousBBIT, 256));
                u16_ABIT = @intCast(@mod(u16_ABIT + PreviousABIT, 256));
            } else if (CURRENT_FILTER_METHOD == 2) {
                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopRBIT: u16 = 0;
                var TopGBIT: u16 = 0;
                var TopBBIT: u16 = 0;
                var TopABIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                    TopBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP];
                    TopABIT = UNCOMPRESSED[BIT_INDEX + 3 - ROW_MOVE_UP];
                }

                u16_RBIT = @intCast(@mod(u16_RBIT + TopRBIT, 256));
                u16_GBIT = @intCast(@mod(u16_GBIT + TopGBIT, 256));
                u16_BBIT = @intCast(@mod(u16_BBIT + TopBBIT, 256));
                u16_ABIT = @intCast(@mod(u16_ABIT + TopABIT, 256));
            } else if (CURRENT_FILTER_METHOD == 3) {
                var PreviousRBIT: u16 = 0;
                var PreviousGBIT: u16 = 0;
                var PreviousBBIT: u16 = 0;
                var PreviousABIT: u16 = 0;

                if (ROW_INDEX >= 4) {
                    PreviousRBIT = UNCOMPRESSED[BIT_INDEX - 4];
                    PreviousGBIT = UNCOMPRESSED[BIT_INDEX - 3];
                    PreviousBBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousABIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopRBIT: u16 = 0;
                var TopGBIT: u16 = 0;
                var TopBBIT: u16 = 0;
                var TopABIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                    TopBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP];
                    TopABIT = UNCOMPRESSED[BIT_INDEX + 3 - ROW_MOVE_UP];
                }

                u16_RBIT = @intCast(@mod(u16_RBIT + @divTrunc((TopRBIT + PreviousRBIT), 2), 256));
                u16_GBIT = @intCast(@mod(u16_GBIT + @divTrunc((TopGBIT + PreviousGBIT), 2), 256));
                u16_BBIT = @intCast(@mod(u16_BBIT + @divTrunc((TopBBIT + PreviousBBIT), 2), 256));
                u16_ABIT = @intCast(@mod(u16_ABIT + @divTrunc((TopABIT + PreviousABIT), 2), 256));
            } else if (CURRENT_FILTER_METHOD == 4) {
                var PreviousRBIT: u16 = 0;
                var PreviousGBIT: u16 = 0;
                var PreviousBBIT: u16 = 0;
                var PreviousABIT: u16 = 0;

                if (ROW_INDEX >= 1) {
                    PreviousRBIT = UNCOMPRESSED[BIT_INDEX - 4];
                    PreviousGBIT = UNCOMPRESSED[BIT_INDEX - 3];
                    PreviousBBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousABIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopRBIT: u16 = 0;
                var TopGBIT: u16 = 0;
                var TopBBIT: u16 = 0;
                var TopABIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                    TopBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP];
                    TopABIT = UNCOMPRESSED[BIT_INDEX + 3 - ROW_MOVE_UP];
                }

                var TopLeftRBIT: u16 = 0;
                var TopLeftGBIT: u16 = 0;
                var TopLeftBBIT: u16 = 0;
                var TopLeftABIT: u16 = 0;

                if (HEIGHT_INDEX > 0 and ROW_INDEX >= 4) {
                    TopLeftRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP - 1];
                    TopLeftGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP - 1];
                    TopLeftBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP - 1];
                    TopLeftABIT = UNCOMPRESSED[BIT_INDEX + 3 - ROW_MOVE_UP - 1];
                }

                const RBIT_P = PreviousRBIT + TopRBIT - TopLeftRBIT;
                const RBIT_A = @abs(RBIT_P - PreviousRBIT);
                const RBIT_B = @abs(RBIT_P - TopRBIT);
                const RBIT_C = @abs(RBIT_P - TopLeftRBIT);
                if (RBIT_A <= RBIT_B and RBIT_A <= RBIT_C) {
                    u16_RBIT = @intCast(@mod(u16_RBIT + RBIT_A, 256));
                } else if (RBIT_B <= RBIT_C) {
                    u16_RBIT = @intCast(@mod(u16_RBIT + RBIT_B, 256));
                } else {
                    u16_RBIT = @intCast(@mod(u16_RBIT + RBIT_C, 256));
                }

                const GBIT_P = PreviousGBIT + TopGBIT - TopLeftGBIT;
                const GBIT_A = @abs(GBIT_P - PreviousGBIT);
                const GBIT_B = @abs(GBIT_P - TopGBIT);
                const GBIT_C = @abs(GBIT_P - TopLeftGBIT);
                if (GBIT_A <= GBIT_B and GBIT_A <= GBIT_C) {
                    u16_GBIT = @intCast(@mod(u16_GBIT + GBIT_A, 256));
                } else if (GBIT_B <= GBIT_C) {
                    u16_GBIT = @intCast(@mod(u16_GBIT + GBIT_B, 256));
                } else {
                    u16_GBIT = @intCast(@mod(u16_GBIT + GBIT_C, 256));
                }

                const BBIT_P = PreviousBBIT + TopBBIT - TopLeftBBIT;
                const BBIT_A = @abs(BBIT_P - PreviousBBIT);
                const BBIT_B = @abs(BBIT_P - TopBBIT);
                const BBIT_C = @abs(BBIT_P - TopLeftBBIT);
                if (BBIT_A <= BBIT_B and BBIT_A <= BBIT_C) {
                    u16_BBIT = @intCast(@mod(u16_BBIT + BBIT_A, 256));
                } else if (BBIT_B <= BBIT_C) {
                    u16_BBIT = @intCast(@mod(u16_BBIT + BBIT_B, 256));
                } else {
                    u16_BBIT = @intCast(@mod(u16_BBIT + BBIT_C, 256));
                }

                const ABIT_P = PreviousABIT + TopABIT - TopLeftABIT;
                const ABIT_A = @abs(ABIT_P - PreviousABIT);
                const ABIT_B = @abs(ABIT_P - TopABIT);
                const ABIT_C = @abs(ABIT_P - TopLeftABIT);
                if (ABIT_A <= ABIT_B and ABIT_A <= ABIT_C) {
                    u16_ABIT = @intCast(@mod(u16_ABIT + ABIT_A, 256));
                } else if (ABIT_B <= ABIT_C) {
                    u16_ABIT = @intCast(@mod(u16_ABIT + ABIT_B, 256));
                } else {
                    u16_ABIT = @intCast(@mod(u16_ABIT + ABIT_C, 256));
                }
            }

            const RBIT: u8 = @intCast(u16_RBIT);
            const GBIT: u8 = @intCast(u16_GBIT);
            const BBIT: u8 = @intCast(u16_BBIT);
            const ABIT: u8 = @intCast(u16_ABIT);

            UNCOMPRESSED[BIT_INDEX] = RBIT;
            UNCOMPRESSED[BIT_INDEX + 1] = GBIT;
            UNCOMPRESSED[BIT_INDEX + 2] = BBIT;
            UNCOMPRESSED[BIT_INDEX + 3] = ABIT;
            const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = RBIT, .G = GBIT, .B = BBIT, .A = ABIT, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

            try PIXELS_WRAPPER.append(CURRENT_PIXEL);
            ROW_INDEX += 4;
        }
        HEIGHT_INDEX += 1;
    }

    return PIXELS_WRAPPER;
}

pub fn get_filter_rgb(gpa: *std.mem.Allocator, uncompressed_data: []u8, IMAGE_HEIGHT: u64, ROW_SIZE: u64) !std.ArrayList(PIXEL_TYPE.PixelStruct) {
    var PIXELS_WRAPPER = std.ArrayList(PIXEL_TYPE.PixelStruct).init(gpa.*);
    const UNCOMPRESSED = uncompressed_data;

    var CURRENT_FILTER_METHOD: u8 = 0;
    var HEIGHT_INDEX: u64 = 0;
    for (0..IMAGE_HEIGHT) |_| {
        var ROW_INDEX: u64 = 0;
        while (true) {
            const BIT_INDEX = HEIGHT_INDEX * ROW_SIZE + ROW_INDEX;

            if (BIT_INDEX >= ROW_SIZE * (HEIGHT_INDEX + 1)) break;
            if (BIT_INDEX >= UNCOMPRESSED.len) break;
            if (ROW_INDEX == 0) {
                CURRENT_FILTER_METHOD = UNCOMPRESSED[BIT_INDEX];
                ROW_INDEX += 1;
                continue;
            }

            if (CURRENT_FILTER_METHOD == 0) { // NO FILTER
                const RBIT = UNCOMPRESSED[BIT_INDEX];
                const GBIT = UNCOMPRESSED[BIT_INDEX + 1];
                const BBIT = UNCOMPRESSED[BIT_INDEX + 2];

                const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = RBIT, .G = GBIT, .B = BBIT, .A = 255, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

                try PIXELS_WRAPPER.append(CURRENT_PIXEL);
                ROW_INDEX += 3;
                continue;
            }

            var u16_RBIT: u16 = UNCOMPRESSED[BIT_INDEX];
            var u16_GBIT: u16 = UNCOMPRESSED[BIT_INDEX + 1];
            var u16_BBIT: u16 = UNCOMPRESSED[BIT_INDEX + 2];

            if (CURRENT_FILTER_METHOD == 1) {
                var PreviousRBIT: u16 = 0;
                var PreviousGBIT: u16 = 0;
                var PreviousBBIT: u16 = 0;

                if (ROW_INDEX >= 3) {
                    PreviousRBIT = UNCOMPRESSED[BIT_INDEX - 3];
                    PreviousGBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousBBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                u16_RBIT = @intCast(@mod(u16_RBIT + PreviousRBIT, 256));
                u16_GBIT = @intCast(@mod(u16_GBIT + PreviousGBIT, 256));
                u16_BBIT = @intCast(@mod(u16_BBIT + PreviousBBIT, 256));
            } else if (CURRENT_FILTER_METHOD == 2) {
                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopRBIT: u16 = 0;
                var TopGBIT: u16 = 0;
                var TopBBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                    TopBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP];
                }

                u16_RBIT = @intCast(@mod(u16_RBIT + TopRBIT, 256));
                u16_GBIT = @intCast(@mod(u16_GBIT + TopGBIT, 256));
                u16_BBIT = @intCast(@mod(u16_BBIT + TopBBIT, 256));
            } else if (CURRENT_FILTER_METHOD == 3) {
                var PreviousRBIT: u16 = 0;
                var PreviousGBIT: u16 = 0;
                var PreviousBBIT: u16 = 0;

                if (ROW_INDEX >= 3) {
                    PreviousRBIT = UNCOMPRESSED[BIT_INDEX - 3];
                    PreviousGBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousBBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopRBIT: u16 = 0;
                var TopGBIT: u16 = 0;
                var TopBBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                    TopBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP];
                }

                u16_RBIT = @intCast(@mod(u16_RBIT + @divTrunc((TopRBIT + PreviousRBIT), 2), 256));
                u16_GBIT = @intCast(@mod(u16_GBIT + @divTrunc((TopGBIT + PreviousGBIT), 2), 256));
                u16_BBIT = @intCast(@mod(u16_BBIT + @divTrunc((TopBBIT + PreviousBBIT), 2), 256));
            } else if (CURRENT_FILTER_METHOD == 4) {
                var PreviousRBIT: u16 = 0;
                var PreviousGBIT: u16 = 0;
                var PreviousBBIT: u16 = 0;

                if (ROW_INDEX >= 1) {
                    PreviousRBIT = UNCOMPRESSED[BIT_INDEX - 3];
                    PreviousGBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousBBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopRBIT: u16 = 0;
                var TopGBIT: u16 = 0;
                var TopBBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                    TopBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP];
                }

                var TopLeftRBIT: u16 = 0;
                var TopLeftGBIT: u16 = 0;
                var TopLeftBBIT: u16 = 0;

                if (HEIGHT_INDEX > 0 and ROW_INDEX >= 4) {
                    TopLeftRBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP - 1];
                    TopLeftGBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP - 1];
                    TopLeftBBIT = UNCOMPRESSED[BIT_INDEX + 2 - ROW_MOVE_UP - 1];
                }

                const RBIT_P = PreviousRBIT + TopRBIT - TopLeftRBIT;
                const RBIT_A = @abs(RBIT_P - PreviousRBIT);
                const RBIT_B = @abs(RBIT_P - TopRBIT);
                const RBIT_C = @abs(RBIT_P - TopLeftRBIT);
                if (RBIT_A <= RBIT_B and RBIT_A <= RBIT_C) {
                    u16_RBIT = @intCast(@mod(u16_RBIT + RBIT_A, 256));
                } else if (RBIT_B <= RBIT_C) {
                    u16_RBIT = @intCast(@mod(u16_RBIT + RBIT_B, 256));
                } else {
                    u16_RBIT = @intCast(@mod(u16_RBIT + RBIT_C, 256));
                }

                const GBIT_P = PreviousGBIT + TopGBIT - TopLeftGBIT;
                const GBIT_A = @abs(GBIT_P - PreviousGBIT);
                const GBIT_B = @abs(GBIT_P - TopGBIT);
                const GBIT_C = @abs(GBIT_P - TopLeftGBIT);
                if (GBIT_A <= GBIT_B and GBIT_A <= GBIT_C) {
                    u16_GBIT = @intCast(@mod(u16_GBIT + GBIT_A, 256));
                } else if (GBIT_B <= GBIT_C) {
                    u16_GBIT = @intCast(@mod(u16_GBIT + GBIT_B, 256));
                } else {
                    u16_GBIT = @intCast(@mod(u16_GBIT + GBIT_C, 256));
                }

                const BBIT_P = PreviousBBIT + TopBBIT - TopLeftBBIT;
                const BBIT_A = @abs(BBIT_P - PreviousBBIT);
                const BBIT_B = @abs(BBIT_P - TopBBIT);
                const BBIT_C = @abs(BBIT_P - TopLeftBBIT);
                if (BBIT_A <= BBIT_B and BBIT_A <= BBIT_C) {
                    u16_BBIT = @intCast(@mod(u16_BBIT + BBIT_A, 256));
                } else if (BBIT_B <= BBIT_C) {
                    u16_BBIT = @intCast(@mod(u16_BBIT + BBIT_B, 256));
                } else {
                    u16_BBIT = @intCast(@mod(u16_BBIT + BBIT_C, 256));
                }
            }

            const RBIT: u8 = @intCast(u16_RBIT);
            const GBIT: u8 = @intCast(u16_GBIT);
            const BBIT: u8 = @intCast(u16_BBIT);

            UNCOMPRESSED[BIT_INDEX] = RBIT;
            UNCOMPRESSED[BIT_INDEX + 1] = GBIT;
            UNCOMPRESSED[BIT_INDEX + 2] = BBIT;
            const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = RBIT, .G = GBIT, .B = BBIT, .A = 255, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

            try PIXELS_WRAPPER.append(CURRENT_PIXEL);
            ROW_INDEX += 3;
        }
        HEIGHT_INDEX += 1;
    }

    return PIXELS_WRAPPER;
}

pub fn get_filter_grayscale(gpa: *std.mem.Allocator, uncompressed_data: []u8, IMAGE_HEIGHT: u64, ROW_SIZE: u64) !std.ArrayList(PIXEL_TYPE.PixelStruct) {
    var PIXELS_WRAPPER = std.ArrayList(PIXEL_TYPE.PixelStruct).init(gpa.*);
    const UNCOMPRESSED = uncompressed_data;

    var CURRENT_FILTER_METHOD: u8 = 0;
    var HEIGHT_INDEX: u64 = 0;
    for (0..IMAGE_HEIGHT) |_| {
        var ROW_INDEX: u64 = 0;
        while (true) {
            const BIT_INDEX = HEIGHT_INDEX * ROW_SIZE + ROW_INDEX;

            if (BIT_INDEX >= ROW_SIZE * (HEIGHT_INDEX + 1)) break;
            if (BIT_INDEX >= UNCOMPRESSED.len) break;
            if (ROW_INDEX == 0) {
                CURRENT_FILTER_METHOD = UNCOMPRESSED[BIT_INDEX];
                ROW_INDEX += 1;
                continue;
            }

            if (CURRENT_FILTER_METHOD == 0) { // NO FILTER
                const graySCALE = UNCOMPRESSED[BIT_INDEX];
                const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = graySCALE, .G = graySCALE, .B = graySCALE, .A = 255, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

                try PIXELS_WRAPPER.append(CURRENT_PIXEL);
                ROW_INDEX += 1;
                continue;
            }

            var u16_graySCALE: u16 = UNCOMPRESSED[BIT_INDEX];

            if (CURRENT_FILTER_METHOD == 1) {
                var PreviousGrayScaleBIT: u16 = 0;

                if (ROW_INDEX >= 1) {
                    PreviousGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                u16_graySCALE = @intCast(@mod(u16_graySCALE + PreviousGrayScaleBIT, 256));
            } else if (CURRENT_FILTER_METHOD == 2) {
                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopGrayScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                }

                u16_graySCALE = @intCast(@mod(u16_graySCALE + TopGrayScaleBIT, 256));
            } else if (CURRENT_FILTER_METHOD == 3) {
                var PreviousGrayScaleBIT: u16 = 0;

                if (ROW_INDEX >= 1) {
                    PreviousGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopGrayScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                }

                u16_graySCALE = @intCast(@mod(u16_graySCALE + @divTrunc((TopGrayScaleBIT + PreviousGrayScaleBIT), 2), 256));
            } else if (CURRENT_FILTER_METHOD == 4) {
                var PreviousGrayScaleBIT: u16 = 0;

                if (ROW_INDEX >= 1) {
                    PreviousGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopGrayScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                }

                var TopLeftGrayScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0 and ROW_INDEX >= 1) {
                    TopLeftGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP - 1];
                }

                const GrayScaleBIT_P = PreviousGrayScaleBIT + TopGrayScaleBIT - TopLeftGrayScaleBIT;
                const GrayScaleBIT_A = @abs(GrayScaleBIT_P - PreviousGrayScaleBIT);
                const GrayScale_B = @abs(GrayScaleBIT_P - TopGrayScaleBIT);
                const GrayScaleBIT_C = @abs(GrayScaleBIT_P - TopLeftGrayScaleBIT);
                if (GrayScaleBIT_A <= GrayScale_B and GrayScaleBIT_A <= GrayScaleBIT_C) {
                    u16_graySCALE = @intCast(@mod(u16_graySCALE + GrayScaleBIT_A, 256));
                } else if (GrayScale_B <= GrayScaleBIT_C) {
                    u16_graySCALE = @intCast(@mod(u16_graySCALE + GrayScale_B, 256));
                } else {
                    u16_graySCALE = @intCast(@mod(u16_graySCALE + GrayScaleBIT_C, 256));
                }
            }

            const grayScale: u8 = @intCast(u16_graySCALE);

            UNCOMPRESSED[BIT_INDEX] = grayScale;
            const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = grayScale, .G = grayScale, .B = grayScale, .A = 255, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

            try PIXELS_WRAPPER.append(CURRENT_PIXEL);
            ROW_INDEX += 1;
        }
        HEIGHT_INDEX += 1;
    }

    return PIXELS_WRAPPER;
}

pub fn get_filter_grayscale_a(gpa: *std.mem.Allocator, uncompressed_data: []u8, IMAGE_HEIGHT: u64, ROW_SIZE: u64) !std.ArrayList(PIXEL_TYPE.PixelStruct) {
    var PIXELS_WRAPPER = std.ArrayList(PIXEL_TYPE.PixelStruct).init(gpa.*);
    const UNCOMPRESSED = uncompressed_data;

    var CURRENT_FILTER_METHOD: u8 = 0;
    var HEIGHT_INDEX: u64 = 0;
    for (0..IMAGE_HEIGHT) |_| {
        var ROW_INDEX: u64 = 0;
        while (true) {
            const BIT_INDEX = HEIGHT_INDEX * ROW_SIZE + ROW_INDEX;

            if (BIT_INDEX >= ROW_SIZE * (HEIGHT_INDEX + 1)) break;
            if (BIT_INDEX >= UNCOMPRESSED.len) break;
            if (ROW_INDEX == 0) {
                CURRENT_FILTER_METHOD = UNCOMPRESSED[BIT_INDEX];
                ROW_INDEX += 1;
                continue;
            }

            if (CURRENT_FILTER_METHOD == 0) { // NO FILTER
                const graySCALE = UNCOMPRESSED[BIT_INDEX];
                const opacitySCALE = UNCOMPRESSED[BIT_INDEX + 1];
                const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = graySCALE, .G = graySCALE, .B = graySCALE, .A = opacitySCALE, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

                try PIXELS_WRAPPER.append(CURRENT_PIXEL);
                ROW_INDEX += 2;
                continue;
            }

            var u16_graySCALE: u16 = UNCOMPRESSED[BIT_INDEX];
            var u16_opacitySCALE: u16 = UNCOMPRESSED[BIT_INDEX + 1];

            if (CURRENT_FILTER_METHOD == 1) {
                var PreviousGrayScaleBIT: u16 = 0;
                var PreviousOpacityScaleBIT: u16 = 0;

                if (ROW_INDEX >= 2) {
                    PreviousGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousOpacityScaleBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                u16_graySCALE = @intCast(@mod(u16_graySCALE + PreviousGrayScaleBIT, 256));
                u16_opacitySCALE = @intCast(@mod(u16_opacitySCALE + PreviousOpacityScaleBIT, 256));
            } else if (CURRENT_FILTER_METHOD == 2) {
                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopGrayScaleBIT: u16 = 0;
                var TopOpacityScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopOpacityScaleBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                }

                u16_graySCALE = @intCast(@mod(u16_graySCALE + TopGrayScaleBIT, 256));
                u16_opacitySCALE = @intCast(@mod(u16_opacitySCALE + TopOpacityScaleBIT, 256));
            } else if (CURRENT_FILTER_METHOD == 3) {
                var PreviousGrayScaleBIT: u16 = 0;
                var PreviousOpacityScaleBIT: u16 = 0;

                if (ROW_INDEX >= 2) {
                    PreviousGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousOpacityScaleBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopGrayScaleBIT: u16 = 0;
                var TopOpacityScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopOpacityScaleBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                }

                u16_graySCALE = @intCast(@mod(u16_graySCALE + @divTrunc((TopGrayScaleBIT + PreviousGrayScaleBIT), 2), 256));
                u16_opacitySCALE = @intCast(@mod(u16_opacitySCALE + @divTrunc((TopOpacityScaleBIT + PreviousOpacityScaleBIT), 2), 256));
            } else if (CURRENT_FILTER_METHOD == 4) {
                var PreviousGrayScaleBIT: u16 = 0;
                var PreviousOpacityScaleBIT: u16 = 0;

                if (ROW_INDEX >= 2) {
                    PreviousGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - 2];
                    PreviousOpacityScaleBIT = UNCOMPRESSED[BIT_INDEX - 1];
                }

                const ROW_MOVE_UP = HEIGHT_INDEX * ROW_SIZE;
                var TopGrayScaleBIT: u16 = 0;
                var TopOpacityScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0) {
                    TopGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP];
                    TopOpacityScaleBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP];
                }

                var TopLeftGrayScaleBIT: u16 = 0;
                var TopLeftOpacityScaleBIT: u16 = 0;

                if (HEIGHT_INDEX > 0 and ROW_INDEX >= 2) {
                    TopLeftGrayScaleBIT = UNCOMPRESSED[BIT_INDEX - ROW_MOVE_UP - 1];
                    TopLeftOpacityScaleBIT = UNCOMPRESSED[BIT_INDEX + 1 - ROW_MOVE_UP - 1];
                }

                const GrayScaleBIT_P = PreviousGrayScaleBIT + TopGrayScaleBIT - TopLeftGrayScaleBIT;
                const GrayScaleBIT_A = @abs(GrayScaleBIT_P - PreviousGrayScaleBIT);
                const GrayScale_B = @abs(GrayScaleBIT_P - TopGrayScaleBIT);
                const GrayScaleBIT_C = @abs(GrayScaleBIT_P - TopLeftGrayScaleBIT);
                if (GrayScaleBIT_A <= GrayScale_B and GrayScaleBIT_A <= GrayScaleBIT_C) {
                    u16_graySCALE = @intCast(@mod(u16_graySCALE + GrayScaleBIT_A, 256));
                } else if (GrayScale_B <= GrayScaleBIT_C) {
                    u16_graySCALE = @intCast(@mod(u16_graySCALE + GrayScale_B, 256));
                } else {
                    u16_graySCALE = @intCast(@mod(u16_graySCALE + GrayScaleBIT_C, 256));
                }

                const OpacityScaleBIT_P = PreviousOpacityScaleBIT + TopOpacityScaleBIT - TopLeftOpacityScaleBIT;
                const OpacityScaleBIT_A = @abs(OpacityScaleBIT_P - PreviousOpacityScaleBIT);
                const OpacityScale_B = @abs(OpacityScaleBIT_P - TopOpacityScaleBIT);
                const OpacityScaleBIT_C = @abs(OpacityScaleBIT_P - TopLeftOpacityScaleBIT);
                if (OpacityScaleBIT_A <= OpacityScale_B and OpacityScaleBIT_A <= OpacityScaleBIT_C) {
                    u16_opacitySCALE = @intCast(@mod(u16_opacitySCALE + OpacityScaleBIT_A, 256));
                } else if (OpacityScale_B <= OpacityScaleBIT_C) {
                    u16_opacitySCALE = @intCast(@mod(u16_opacitySCALE + OpacityScale_B, 256));
                } else {
                    u16_opacitySCALE = @intCast(@mod(u16_opacitySCALE + OpacityScaleBIT_C, 256));
                }
            }

            const grayScale: u8 = @intCast(u16_graySCALE);
            const opacityScale: u8 = @intCast(u16_opacitySCALE);

            UNCOMPRESSED[BIT_INDEX] = grayScale;
            const CURRENT_PIXEL = PIXEL_TYPE.PixelStruct{ .R = grayScale, .G = grayScale, .B = grayScale, .A = opacityScale, .COLUMN_INDEX = HEIGHT_INDEX, .ROW_INDEX = @divTrunc((ROW_INDEX - 1), 4) };

            try PIXELS_WRAPPER.append(CURRENT_PIXEL);
            ROW_INDEX += 2;
        }
        HEIGHT_INDEX += 1;
    }

    return PIXELS_WRAPPER;
}
