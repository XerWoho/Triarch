pub const BINARY_BASE: u2 = 2;

pub const BIT_LENGTH: u4 = 1;
pub const BYTE_LENGTH: u8 = 8;


pub const PNG_SIG = "89504e470d0a1a0a";
pub const PNG_SIG_POSITION = [2]u8{0, 16};

pub const IHDR_SIG = "49484452";
pub const IHDR_SIZE_POSITION = [2]u8{16,24};

pub const IHDR_HEADER_POSITION = [2]u8{24, 32};
pub const IHDR_START = 32;

pub const LETTERS: [6][]const u8 = .{ "a", "b", "c", "d", "e", "f" };

pub const HEX_KEYS = [_]u8{
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
};

pub const HEX_VALUES = [_][]const u8{
	"0000",
	"0001",
	"0010",
	"0011",
	"0100",
	"0101",
	"0110",
	"0111",
	"1000",
	"1001",
	"1010",
	"1011",
	"1100",
	"1101",
	"1110",
	"1111"
};