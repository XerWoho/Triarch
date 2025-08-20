pub const HUFFMANStruct = struct {
    btype: u2,
    bfinal: u1,
    hclen: u32,
    hdist: u32,
    hlit: u16,
};

pub const CODE_LENGTH_SYMBOLS = struct { symbol: u16, bits_length: u8, huffman_code: []u8 };
