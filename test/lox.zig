const std = @import("std");
const testing = std.testing;

pub const TokenizerTests = @import("lox/Tokenizer.zig");
pub const ParserTests = @import("lox/Parser.zig");

test {
    testing.refAllDeclsRecursive(@This());
}
