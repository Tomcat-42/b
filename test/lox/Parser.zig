const std = @import("std");
const testing = std.testing;
const expectEqualDeep = testing.expectEqualDeep;
const allocator = testing.allocator;

const lox = @import("lox");
const Tokenizer = lox.Tokenizer;
const Parser = lox.Parser;
const Program = Parser.Program;

