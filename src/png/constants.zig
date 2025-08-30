pub const BINARY_BASE: u2 = 2;
pub const DEF_BASE_LENGTH: u8 = 3;

pub const BIT_LENGTH: u4 = 1;
pub const BYTE_LENGTH: u8 = 8;

pub const INT_TO_ASCII_OFFSET: u8 = 48; // the different to go from the string "0" to the int 0 in binary

pub const PNG_SIG = "89504e470d0a1a0a";
pub const PLTE_SIG = "504C5445";
pub const IHDR_SIG = "49484452";
pub const IDAT_SIG = "49444154";
pub const IEND_SIG = "49454e44";

pub const bKGD_SIG = "624b4744";
pub const cHRM_SIG = "6348524d";
pub const cICP_SIG = "63494350";
pub const dSIG_SIG = "64534947";
pub const eXIf_SIG = "65584966";
pub const gAMA_SIG = "67414d41";
pub const hIST_SIG = "68495354";
pub const iCCP_SIG = "69434350";
pub const iTXt_SIG = "69545874";
pub const pHYs_SIG = "70485973";
pub const sBIT_SIG = "73424954";
pub const sPLT_SIG = "73504c54";
pub const sRGB_SIG = "73524742";
pub const sTER_SIG = "73544552";
pub const tEXt_SIG = "74455874";
pub const tIME_SIG = "74494d45";
pub const tRNS_SIG = "74524e53";
pub const zTXt_SIG = "7a545874";

pub const HEX_LETTERS: [6][]const u8 = .{ "a", "b", "c", "d", "e", "f" };
pub const HEX_KEYS = [_]u8{
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
};
pub const HEX_VALUES = [_][]const u8{ "0000", "0001", "0010", "0011", "0100", "0101", "0110", "0111", "1000", "1001", "1010", "1011", "1100", "1101", "1110", "1111" };

pub const HCLEN_ORDER = [19]u32{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

pub const RGB_WHITE: u8 = 255;
pub const RGB_BLACK: u8 = 0;


pub const R_FLOAT_COEFFICIENTS: f32 = 0.299;
pub const G_FLOAT_COEFFICIENTS: f32 = 0.587;
pub const B_FLOAT_COEFFICIENTS: f32 = 0.114;

pub const BASE_DISTANCES: [30]u16 = .{
    1,     2,     3,    4,
    5,     7,     9,    13,
    17,    25,    33,   49,
    65,    97,    129,  193,
    257,   385,   513,  769,
    1025,  1537,  2049, 3073,
    4097,  6145,  8193, 12289,
    16385, 24577,
};

pub const EXTRA_BITS: [30]u8 = .{
    0,  0,  0,  0,
    1,  1,  2,  2,
    3,  3,  4,  4,
    5,  5,  6,  6,
    7,  7,  8,  8,
    9,  9,  10, 10,
    11, 11, 12, 12,
    13, 13,
};


pub const HEX_PRINT_AMOUNT = 2;
pub const HEX_SECTION_LENGTH = 8;
pub const HEX_BYTE_AMONUT = HEX_PRINT_AMOUNT * HEX_SECTION_LENGTH;