pub const HUFFMANStruct = struct {
    btype: u8,
    bfinal: u8,
    hclen: u32,
    hdist: u32,
    hlit: u16,
};
