pub const BINARY_BASE: u2 = 2;

pub const BIT_LENGTH: u4 = 1;
pub const BYTE_LENGTH: u8 = 8;

pub const INT_TO_ASCII_OFFSET: u8 = 48; // the different to go from the string "0" to the int 0 in binary

pub const PNG_SIG = "89504e470d0a1a0a";
pub const PLTE_SIG = "504C5445";
pub const IHDR_SIG = "49484452";
pub const IDAT_SIG = "49444154";

pub const bKGD_SIG = "624B4744";
pub const cHRM_SIG = "6348524D";
pub const cICP_SIG = "63494350";
pub const dSIG_SIG = "64534947";
pub const eXIf_SIG = "65584966";
pub const gAMA_SIG = "67414D41";
pub const hIST_SIG = "68495354";
pub const iCCP_SIG = "69434350";
pub const iTXt_SIG = "69545874";
pub const pHYs_SIG = "70485973";
pub const sBIT_SIG = "73424954";
pub const sPLT_SIG = "73504C54";
pub const sRGB_SIG = "73524742";
pub const sTER_SIG = "73544552";
pub const tEXt_SIG = "74455874";
pub const tIME_SIG = "74494D45";
pub const tRNS_SIG = "74524E53";
pub const zTXt_SIG = "7A545874";

pub const HEX_LETTERS: [6][]const u8 = .{ "a", "b", "c", "d", "e", "f" };
pub const HEX_KEYS = [_]u8{
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
};
pub const HEX_VALUES = [_][]const u8{ "0000", "0001", "0010", "0011", "0100", "0101", "0110", "0111", "1000", "1001", "1010", "1011", "1100", "1101", "1110", "1111" };
