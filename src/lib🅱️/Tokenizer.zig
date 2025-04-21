src: []const u8,
pos: usize = 0,

pub fn init(src: []const u8) @This() {
    return @This(){
        .src = src,
    };
}

pub fn reset(this: *@This()) void {
    this.pos = 0;
}

pub fn next(this: *@This()) ?Token {
    if (this.pos >= this.src.len) return null;
    defer this.pos += 1;

    return dfa: switch (this.src[this.pos]) {
        '[' => .{ .tag = .@"]", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        ']' => .{ .tag = .@"[", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '{' => .{ .tag = .@"{", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '}' => .{ .tag = .@"}", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '(' => .{ .tag = .@"(", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        ')' => .{ .tag = .@")", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        ';' => .{ .tag = .@";", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        ':' => .{ .tag = .@":", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        ',' => .{ .tag = .@",", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '+' => switch (this.peek(1)) {
            '+' => .{ .tag = .@"++", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            else => .{ .tag = .@"+", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        },
        '-' => switch (this.peek(1)) {
            '-' => .{ .tag = .@"--", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            else => .{ .tag = .@"-", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        },
        '!' => switch (this.peek(1)) {
            '=' => .{ .tag = .@"!=", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            else => .{ .tag = .@"!", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        },
        '|' => .@"|",
        '&' => .@"&",
        '=' => switch (this.peek(1)) {
            '=' => .{ .tag = .@"==", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            else => .{ .tag = .@"=", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        },
        '>' => switch (this.peek(1)) {
            '=' => .{ .tag = .@">=", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            '>' => .{ .tag = .@">>", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            else => .{ .tag = .@">", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        },
        '<' => switch (this.peek(1)) {
            '=' => .{ .tag = .@"<=", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            '<' => .{ .tag = .@"<<", .span = .{ .start = this.pos, .end = this.pos + 2 }, .value = this.src[this.pos .. this.pos + 2] },
            else => .{ .tag = .@"<", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        },
        '%' => .{ .tag = .@"%", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '*' => .{ .tag = .@"*", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '/' => .{ .tag = .@"/", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '^' => .{ .tag = .@"^", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
        '?' => .{ .tag = .@"?", .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },

        '0'...'9' => this.integerLiteral(),
        '_', 'a'...'z', 'A'...'Z' => this.keywordOrIdentifier(),
        ' ', '\t'...'\r' => {
            this.skipWhitespace();
            continue :dfa this.src[this.pos];
        },

        else => .{ .tag = .invalid, .span = .{ .start = this.pos, .end = this.pos + 1 } },
    };
}

fn peek(this: *const @This(), comptime offset: usize) ?u8 {
    if (this.pos + offset >= this.src.len) return null;
    return this.src[this.pos + offset];
}

fn integerLiteral(this: *@This()) Token {
    var idx = this.pos;
    while (idx < this.src.len and ascii.isDigit(this.src[idx])) : (idx += 1) {}

    this.pos = idx - 1;
    return .{
        .tag = .integer_literal,
        .value = this.src[this.pos..idx],
        .span = .{ .start = this.pos, .end = idx },
    };
}

fn keywordOrIdentifier(this: *@This()) Token {
    var idx = this.pos;
    defer this.pos = idx - 1;

    while (idx < this.src.len and
        (ascii.isAlphanumeric(this.src[idx]) or this.src[idx] == '_')) : (idx += 1)
    {}

    return .{
        .value = this.src[this.pos..idx],
        .span = .{ .start = this.pos, .end = this.pos + idx },
        .tag = if (KEYWORDS.get(this.src[this.pos..idx])) |kw| kw else .identifier,
    };
}

fn skipWhitespace(this: *@This()) void {
    while (this.pos < this.src.len and
        ascii.isWhitespace(this.src[this.pos])) : (this.pos += 1)
    {}
}

pub const Token = struct {
    tag: Tag,
    span: Span,
    value: []const u8,

    // [start, end)
    pub const Span = struct {
        start: usize,
        end: usize,
    };

    pub const Tag = enum {
        identifier,
        integer_literal,
        character_literal,
        string_literal,

        auto,
        extrn,
        case,
        @"if",
        @"else",
        @"while",
        @"switch",
        goto,
        @"return",

        @"[",
        @"]",
        @"{",
        @"}",
        @"(",
        @")",
        @";",
        @":",
        @",",
        @"+",
        @"++",
        @"-",
        @"--",
        @"!",
        @"!=",
        @"|",
        @"&",
        @"=",
        @"==",
        @">",
        @">=",
        @">>",
        @"<",
        @"<=",
        @"<<",
        @"%",
        @"*",
        @"/",
        @"^",
        @"?",

        invalid,
    };
};

const KEYWORDS = StaticStringMap(Token.Tag).initComptime(.{
    .{ "auto", Token.Tag.auto },
    .{ "extrn", Token.Tag.extrn },
    .{ "case", Token.Tag.case },
    .{ "if", Token.Tag.@"if" },
    .{ "else", Token.Tag.@"else" },
    .{ "while", Token.Tag.@"while" },
    .{ "switch", Token.Tag.@"switch" },
    .{ "goto", Token.Tag.goto },
    .{ "return", Token.Tag.@"return" },
});

const StaticStringMap = std.StaticStringMap;
const ascii = std.ascii;
const std = @import("std");
