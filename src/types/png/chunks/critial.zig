pub const PLTEStruct = struct {
    size: u32,

    red: u8,
    green: u8,
    blue: u8,

    crc: []u8,
};

pub const IHDRStruct = struct {
    size: u32,
    width: u16,
    height: u16,
    bits_per_pixel: u8,
    color_type: u8,
    compression_method: u8,
    filter_method: u8,
    interlaced: bool,
    crc: []u8,
};

pub const IDATStruct = struct { size: u32, compression_method: u8, compression_info: u16, zlib_fcheck_value: u32, zlib_checksum: u16, crc: []u8, data: []u8 };

pub const IENDStruct = struct {
    size: u32,
    crc: []u8,
};
