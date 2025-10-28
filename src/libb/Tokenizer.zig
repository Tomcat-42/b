const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Io = std.Io;
const assert = std.debug.assert;
const builtin = std.builtin;
const StaticStringMap = std.StaticStringMap;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const util = @import("util.zig");
const term = util.term;

const Tokenizer = @This();

src: []const u8,
pos: usize = 0,

pub fn init(src: []const u8) Tokenizer {
    return .{ .src = src };
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
            if (this.nextChar()) |c| switch (c) {
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
            if (this.nextChar()) |c| switch (c) {
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
            if (this.nextChar()) |c| switch (c) {
                '*' => break :dfa this.parseComment(),
                else => {},
            };

            break :dfa .{
                .tag = .@"/",
                .span = .{ .start = this.pos, .end = this.pos + 1 },
                .value = this.src[this.pos .. this.pos + 1],
            };
        },
        '!' => {
            if (this.nextChar()) |c| switch (c) {
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
            if (this.nextChar()) |c| switch (c) {
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
            if (this.nextChar()) |c| switch (c) {
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
            if (this.nextChar()) |c| switch (c) {
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
            if (this.nextChar()) |c| switch (c) {
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
            if (this.nextChar()) |c| switch (c) {
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
        '\'' => this.parseCharacterLiteral(),
        '0'...'9' => this.parseIntegerLiteral(),
        '_', 'a'...'z', 'A'...'Z' => this.parseKeywordOrIdentifier(),
        ' ', '\t'...'\r' => {
            this.skipWhitespace();
            continue :dfa this.src[this.pos];
        },

        else => .{ .tag = .invalid, .span = .{ .start = this.pos, .end = this.pos + 1 }, .value = this.src[this.pos .. this.pos + 1] },
    };
}

pub fn hasNext(this: *@This()) bool {
    return this.lookahead(1) != null;
}

pub fn lookahead(this: *Tokenizer, comptime k: usize) ?Token {
    const old = this.pos;
    defer this.pos = old;

    inline for (0..k - 1) |_| _ = this.next();
    return this.next();
}

pub fn expect(this: *@This(), expected: anytype, la: usize) ?Token {
    assert(@typeInfo(@TypeOf(expected)) == .@"struct");

    const token = this.lookahead(la) orelse return null;
    inline for (expected) |e| switch (token.tag) {
        e => return this.next(),
        else => {},
    };

    return null;
}

pub fn sync(this: *@This(), expected: anytype) ?Token {
    return token: while (this.lookahead(1)) |_| {
        if (this.expect(expected)) |t| break :token t;
        _ = this.next();
    } else null;
}

pub fn collect(this: *@This(), allocator: Allocator) ![]const Token {
    var tokens = try ArrayList(Token).initCapacity(allocator, 1024);
    errdefer tokens.deinit(allocator);

    while (this.next()) |token| try tokens.append(allocator, token);
    return tokens.toOwnedSlice(allocator);
}

fn nextChar(this: *Tokenizer) ?u8 {
    return if (this.pos + 1 >= this.src.len) return null else this.src[this.pos + 1];
}

fn parseIntegerLiteral(this: *Tokenizer) Token {
    var idx = this.pos;
    while (idx < this.src.len and ascii.isDigit(this.src[idx])) : (idx += 1) {}

    this.pos = idx - 1;
    return .{
        .tag = .integer_literal,
        .value = this.src[this.pos..idx],
        .span = .{ .start = this.pos, .end = idx },
    };
}

fn parseCharacterLiteral(this: *Tokenizer) ?Token {
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

fn parseKeywordOrIdentifier(this: *Tokenizer) Token {
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
fn parseComment(this: *Tokenizer) ?Token {
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

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .token = this } };
    }

    const Format = struct {
        depth: usize = 0,
        token: *const Token,

        pub fn format(this: @This(), writer: *Io.Writer) Io.Writer.Error!void {
            const depth = this.depth;
            for (0..depth) |_| try writer.print(term.SEP, .{});

            switch (this.token.tag) {
                .integer_literal,
                .character_literal,
                .string_literal,
                => try writer.print("{s}Token{{.{t} = {s}{s}{s}}}{s}\n", .{
                    term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    this.token.tag,
                    term.FG.WHITE ++ term.FG.EFFECT.UNDERLINE,
                    this.token.value,
                    term.FG.MAGENTA ++ term.FG.EFFECT.RESET.UNDERLINE,
                    term.RESET,
                }),
                .identifier => try writer.print("{s}Token{{.{t} = {s}{s}{s}}}{s}\n", .{
                    term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    this.token.tag,
                    term.FG.WHITE ++ term.FG.EFFECT.UNDERLINE,
                    this.token.value,
                    term.RESET ++ term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    term.RESET,
                }),
                else => try writer.print("{s}Token.{t}{s}\n", .{
                    term.FG.MAGENTA ++ term.FG.EFFECT.ITALIC,
                    this.token.tag,
                    term.RESET,
                }),
            }
        }
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

