const std = @import("std");
const testing = std.testing;

pub const TokenizerTests = @import("libb/Tokenizer.zig");
pub const ParserTests = @import("libb/Tokenizer.zig");

test {
    testing.refAllDeclsRecursive(@This());
}
