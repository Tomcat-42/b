const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const lox = @import("lox");
const Tokenizer = lox.Tokenizer;
const Token = Tokenizer.Token;

const Parser = @This();

tokens: *Tokenizer,
errors: ArrayList(Error) = .empty,

pub fn init(tokens: *Tokenizer) Parser {
    return .{ .tokens = tokens };
}

pub fn deinit(this: *Parser, allocator: Allocator) void {
    this.errors.deinit(allocator);
}

pub fn parse(this: *Parser, allocator: Allocator) !?Program {
    _ = this; // autofix
    _ = allocator; // autofix
    return .{};
}

pub fn reset(this: *Parser, allocator: Allocator) void {
    this.tokens.reset();
    this.errors.clearAndFree(allocator);
}

pub fn getErrors(this: *@This()) !?[]const Error {
    if (this.errors.items.len == 0) return null;
    return this.errors.items;
}

inline fn lookaheadExpectOrHandleErrorAndSync(
    this: *Parser,
    allocator: Allocator,
    comptime expected: anytype,
) !?Token {
    assert(@typeInfo(@TypeOf(expected)) == .@"struct");
    assert(@typeInfo(@TypeOf(expected)).@"struct".fields.len >= 1);

    // Next token is expected, return gracefully 😄
    if (this.tokens.expect(expected)) |token| return token;

    // 💀
    const token = this.tokens.peek();
    try this.errors.append(allocator, .{
        .message = try fmt.allocPrint(allocator, "Expected {s}, got '{s}'", .{
            comptime tokens: {
                var message: []const u8 = "'" ++ @tagName(expected[0]) ++ "'";
                for (1..@typeInfo(@TypeOf(expected)).@"struct".fields.len) |i| message = message ++ ", '" ++ @tagName(expected[i]) ++ "'";
                break :tokens message;
            },
            if (token) |t| @tagName(t.tag) else "Unexpected EOF",
        }),
        .span = if (token) |t| .{
            .begin = this.tokens.pos + 1,
            .end = this.tokens.pos + t.value.len + 1,
        } else .{
            .begin = this.tokens.pos,
            .end = this.tokens.pos,
        },
    });

    return this.tokens.sync(expected);
}

pub const Error = struct {
    message: []const u8,
    span: Span,

    const Span = struct {
        begin: usize,
        end: usize,
    };
};

pub const Program = struct {};
