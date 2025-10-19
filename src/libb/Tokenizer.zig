const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const builtin = std.builtin;
const StaticStringMap = std.StaticStringMap;
const ascii = std.ascii;

const Tokenizer = @This();

src: []const u8,
pos: usize = 0,

pub fn init(src: []const u8) Tokenizer {
    return Tokenizer{
        .src = src,
    };
}

pub fn reset(this: *Tokenizer) void {
    this.pos = 0;
}

pub fn next(this: *Tokenizer) ?Token {
    if (this.pos >= this.src.len) return null;
    defer this.pos += 1;

    return dfa: switch (this.src[this.pos]) {
        '[' => .{
            .tag = .@"[",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        ']' => .{
            .tag = .@"]",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        '{' => .{
            .tag = .@"{",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        '}' => .{
            .tag = .@"}",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        '(' => .{
            .tag = .@"(",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        ')' => .{
            .tag = .@")",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        ';' => .{
            .tag = .@";",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        ':' => .{
            .tag = .@":",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        ',' => .{
            .tag = .@",",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        '+' => {
            if (this.peek(1)) |tok| switch (tok) {
                '+' => break :dfa .{
                    .tag = .@"++",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@"+",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '-' => {
            if (this.peek(1)) |tok| switch (tok) {
                '-' => break :dfa .{
                    .tag = .@"--",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@"-",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '*' => .{
            .tag = .@"*",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        '/' => {
            if (this.peek(1)) |tok| switch (tok) {
                '*' => break :dfa this.comment(),
                else => {},
            };

            break :dfa .{
                .tag = .@"/",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '!' => {
            if (this.peek(1)) |tok| switch (tok) {
                '=' => break :dfa .{
                    .tag = .@"!=",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@"!",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '=' => {
            if (this.peek(1)) |tok| switch (tok) {
                '=' => break :dfa .{
                    .tag = .@"==",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@"=",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '>' => {
            if (this.peek(1)) |tok| switch (tok) {
                '=' => break :dfa .{
                    .tag = .@">=",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                '>' => break :dfa .{
                    .tag = .@">>",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@">",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '<' => {
            if (this.peek(1)) |tok| switch (tok) {
                '=' => break :dfa .{
                    .tag = .@"<=",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                '<' => break :dfa .{
                    .tag = .@"<<",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@"<",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '|' => {
            if (this.peek(1)) |tok| switch (tok) {
                '|' => break :dfa .{
                    .tag = .@"||",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@"|",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '&' => {
            if (this.peek(1)) |tok| switch (tok) {
                '&' => break :dfa .{
                    .tag = .@"&&",
                    .span = .{ .start = this.pos, .end = this.pos + 2 },
                    .value = this.src[this.pos .. this.pos + 2],
                },
                else => {},
            };

            break :dfa .{
                .tag = .@"&",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '%' => .{
            .tag = .@"%",
            .span = .{ .start = this.pos, .end = this.pos + 1 },
            .value = this.src[this.pos .. this.pos + 1],
        },
        '\'' => this.characterLiteral(),
        '0'...'9' => this.integerLiteral(),
        '_', 'a'...'z', 'A'...'Z' => this.keywordOrIdentifier(),
        ' ', '\t'...'\r' => {
            this.skipWhitespace();
            continue :dfa this.src[this.pos];
        },

        else => .{ .tag = .invalid, .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
    };
}

fn peek(this: *const Tokenizer, comptime offset: usize) ?u8 {
    if (this.pos + offset >= this.src.len) return null;
    return this.src[this.pos + offset];
}

fn integerLiteral(this: *Tokenizer) Token {
    var idx = this.pos;
    while (idx < this.src.len and ascii.isDigit(this.src[idx])) : (idx += 1) {}

    this.pos = idx - 1;
    return .{
        .tag = .integer_literal,
        .value = this.src[this.pos..idx],
        .span = .{ .start = this.pos, .end = idx },
    };
}

fn characterLiteral(this: *Tokenizer) ?Token {
    this.pos += 1;

    const begin = this.pos;

    while (this.pos < this.src.len) : (this.pos += 1) if (this.src[this.pos] == '\'') {
        const end = this.pos;
        return .{
            .tag = .character_literal,
            .span = .{ .start = begin, .end = end },
            .value = this.src[begin..end],
        };
    };

    return null;
}

fn keywordOrIdentifier(this: *Tokenizer) Token {
    var idx = this.pos;
    defer this.pos = idx - 1;

    while (idx < this.src.len and
        (ascii.isAlphanumeric(this.src[idx]) or this.src[idx] == '_')) : (idx += 1)
    {}

    return .{
        .value = this.src[this.pos..idx],
        .span = .{ .start = this.pos, .end = idx },
        .tag = if (KEYWORDS.get(this.src[this.pos..idx])) |kw| kw else .identifier,
    };
}

fn skipWhitespace(this: *Tokenizer) void {
    while (this.pos < this.src.len and
        ascii.isWhitespace(this.src[this.pos])) : (this.pos += 1)
    {}
}

// the token value str doesn't include the "/* */"s
fn comment(this: *Tokenizer) ?Token {
    this.pos += 2;

    const begin = this.pos;
    var window = mem.window(u8, this.src[this.pos..], 2, 1);

    while (window.next()) |c| : (this.pos += 1) if (mem.eql(u8, c, "*/")) {
        const end = this.pos;
        this.pos += 2;

        return .{
            .tag = .comment,
            .span = .{ .start = begin, .end = end },
            .value = this.src[begin..end],
        };
    };

    return null;
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
        comment,

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
        @"||",
        @"&",
        @"&&",
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
    .{ "auto", .auto },
    .{ "extrn", .extrn },
    .{ "case", .case },
    .{ "if", .@"if" },
    .{ "else", .@"else" },
    .{ "while", .@"while" },
    .{ "switch", .@"switch" },
    .{ "goto", .goto },
    .{ "return", .@"return" },
});

test "parse comment: happy" {
    const expectEqualDeep = std.testing.expectEqualDeep;
    const input =
        \\/* Yes */
    ;

    const expected: []const Token = &.{.{
        .tag = .comment,
        .span = .{ .start = 2, .end = 7 },
        .value = " Yes ",
    }};

    var actual = Tokenizer.init(input);
    var i: usize = 0;
    while (actual.next()) |a| : (i += 1) try expectEqualDeep(expected[i], a);

    try expectEqualDeep(actual.next(), null);
}

test "simple input" {
    const expectEqualDeep = std.testing.expectEqualDeep;

    const input =
        \\/* The following function will print a non-negative number, n, to
        \\   the base b, where 2<=b<=10.  This routine uses the fact that
        \\   in the ASCII character set, the digits 0 to 9 have sequential
        \\   code values.  */
        \\
        \\printn(n,b) {
        \\   extrn putchar;
        \\   auto a;
        \\   /* Wikipedia note: the auto keyword declares a variable with
        \\      automatic storage (lifetime is function scope), not
        \\      "automatic typing" as in C++11. */
        \\
        \\   if(a=n/b) /* assignment, not test for equality */
        \\      printn(a, b); /* recursive */
        \\   putchar(n%b + '0');
        \\}
    ;

    const expected: []const Token = &.{
        .{ .tag = .comment, .span = .{ .start = 2, .end = 212 }, .value = input[2..212] },
        .{ .tag = .identifier, .span = .{ .start = 216, .end = 222 }, .value = "printn" },
        .{ .tag = .@"(", .span = .{ .start = 222, .end = 223 }, .value = "(" },
        .{ .tag = .identifier, .span = .{ .start = 223, .end = 224 }, .value = "n" },
        .{ .tag = .@",", .span = .{ .start = 224, .end = 225 }, .value = "," },
        .{ .tag = .identifier, .span = .{ .start = 225, .end = 226 }, .value = "b" },
        .{ .tag = .@")", .span = .{ .start = 226, .end = 227 }, .value = ")" },
        .{ .tag = .@"{", .span = .{ .start = 228, .end = 229 }, .value = "{" },
        .{ .tag = .extrn, .span = .{ .start = 233, .end = 238 }, .value = "extrn" },
        .{ .tag = .identifier, .span = .{ .start = 239, .end = 246 }, .value = "putchar" },
        .{ .tag = .@";", .span = .{ .start = 246, .end = 247 }, .value = ";" },
        .{ .tag = .auto, .span = .{ .start = 251, .end = 255 }, .value = "auto" },
        .{ .tag = .identifier, .span = .{ .start = 256, .end = 257 }, .value = "a" },
        .{ .tag = .@";", .span = .{ .start = 257, .end = 258 }, .value = ";" },
        .{ .tag = .comment, .span = .{ .start = 264, .end = 419 }, .value = input[264..419] },
        .{ .tag = .@"if", .span = .{ .start = 426, .end = 428 }, .value = "if" },
        .{ .tag = .@"(", .span = .{ .start = 428, .end = 429 }, .value = "(" },
        .{ .tag = .identifier, .span = .{ .start = 429, .end = 430 }, .value = "a" },
        .{ .tag = .@"=", .span = .{ .start = 430, .end = 431 }, .value = "=" },
        .{ .tag = .identifier, .span = .{ .start = 431, .end = 432 }, .value = "n" },
        .{ .tag = .@"/", .span = .{ .start = 432, .end = 433 }, .value = "/" },
        .{ .tag = .identifier, .span = .{ .start = 433, .end = 434 }, .value = "b" },
        .{ .tag = .@")", .span = .{ .start = 434, .end = 435 }, .value = ")" },
        .{ .tag = .comment, .span = .{ .start = 438, .end = 473 }, .value = input[438..473] },
        .{ .tag = .identifier, .span = .{ .start = 482, .end = 488 }, .value = "printn" },
        .{ .tag = .@"(", .span = .{ .start = 488, .end = 489 }, .value = "(" },
        .{ .tag = .identifier, .span = .{ .start = 489, .end = 490 }, .value = "a" },
        .{ .tag = .@",", .span = .{ .start = 490, .end = 491 }, .value = "," },
        .{ .tag = .identifier, .span = .{ .start = 492, .end = 493 }, .value = "b" },
        .{ .tag = .@")", .span = .{ .start = 493, .end = 494 }, .value = ")" },
        .{ .tag = .@";", .span = .{ .start = 494, .end = 495 }, .value = ";" },
        .{ .tag = .comment, .span = .{ .start = 498, .end = 509 }, .value = " recursive " },
        .{ .tag = .identifier, .span = .{ .start = 515, .end = 522 }, .value = "putchar" },
        .{ .tag = .@"(", .span = .{ .start = 522, .end = 523 }, .value = "(" },
        .{ .tag = .identifier, .span = .{ .start = 523, .end = 524 }, .value = "n" },
        .{ .tag = .@"%", .span = .{ .start = 524, .end = 525 }, .value = "%" },
        .{ .tag = .identifier, .span = .{ .start = 525, .end = 526 }, .value = "b" },
        .{ .tag = .@"+", .span = .{ .start = 527, .end = 528 }, .value = "+" },
        .{ .tag = .character_literal, .span = .{ .start = 530, .end = 531 }, .value = "0" },
        .{ .tag = .@")", .span = .{ .start = 532, .end = 533 }, .value = ")" },
        .{ .tag = .@";", .span = .{ .start = 533, .end = 534 }, .value = ";" },
        .{ .tag = .@"}", .span = .{ .start = 535, .end = 536 }, .value = "}" },
    };

    var actual = Tokenizer.init(input);
    var i: usize = 0;
    while (actual.next()) |t| : (i += 1) try expectEqualDeep(expected[i], t);
}
