const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const libb = @import("libb");
const Tokenizer = libb.Tokenizer;
const Token = Tokenizer.Token;

const Parser = @This();
tokens: Tokenizer,
errors: ArrayList(Error) = .empty,

pub fn init(tokens: *Tokenizer) Parser {
    return .{ .tokens = tokens };
}

pub fn deinit(this: *Parser, allocator: Allocator) void {
    this.errors.deinit(allocator);
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
    lookahead: usize,
) !?Token {
    assert(@typeInfo(@TypeOf(expected)) == .@"struct");
    assert(@typeInfo(@TypeOf(expected)).@"struct".fields.len >= 1);
    assert(lookahead >= 1);

    // Next token is expected, return gracefully 😄
    if (this.tokens.expect(expected, lookahead)) |token| return token;

    // 💀
    const token = this.tokens.lookahead(lookahead);
    try this.errors.append(.{
        .message = try fmt.allocPrint(allocator, "Expected {s}, got '{s}'", .{
            comptime tokens: {
                var message: []const u8 = "'" ++ @tagName(expected[0]) ++ "'";
                for (1..@typeInfo(@TypeOf(expected)).@"struct".fields.len) |i| message = message ++ ", '" ++ @tagName(expected[i]) ++ "'";
                break :tokens message;
            },
            if (token) |t| @tagName(t) else "Unexpected EOF",
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

const Error = struct {
    message: []const u8,
    span: Span,

    const Span = struct {
        begin: usize,
        end: usize,
    };
};

pub const Program = struct {
    definitions: ArrayList(Definition),

    pub fn parse(parser: *Parser, allocator: Allocator) @This() {
        var definitions: ArrayList(void) = .empty;
        errdefer definitions.deinit(allocator);

        while (parser.tokens.hasNext())
            if (try Definition.parse(parser, allocator)) |definition|
                try definitions.append(definition);

        return .{ .definitions = definitions };
    }

    pub const Definition = union(enum) {
        var_definition: VarDefinition,
        fn_definition: FnDefinition,

        pub fn parse(parser: *Parser, allocator: Allocator) !@This() {
            const lookahead = try parser.lookaheadExpectOrHandleErrorAndSync(
                allocator,
                .{.@"("},
                2,
            ) orelse return null;

            return switch (lookahead.tag) {
                .@"(" => .{ .fn_definition = try FnDefinition.parse(parser, allocator) },
                else => unreachable,
            };
        }

        const VarDefinition = struct {};

        pub const FnDefinition = struct {
            name: Token,
            @"(": Token,
            parameters: ?FnParameters,
            @")": Token,
            statement: void,

            pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
                const name = try parser.lookaheadExpectOrHandleErrorAndSync(.{Token.Tag.identifier}) orelse return null;
                const @"(" = try parser.lookaheadExpectOrHandleErrorAndSync(.{Token.Tag.@"("}) orelse return null;

                const parameters: ?FnParameters = params: {
                    const lookahead = parser.tokens.lookahead(1);
                    if (lookahead != null and lookahead.?.tag == .@")") break :params null;

                    break :params try FnParameters.parse(parser, allocator);
                };

                const @")" = try parser.lookaheadExpectOrHandleErrorAndSync(.{Token.Tag.@")"}) orelse return null;
                const statement = {};

                return .{
                    .name = name,
                    .@"(" = @"(",
                    .parameters = parameters,
                    .@")" = @")",
                    .statement = statement,
                };
            }

            pub const FnParameters = struct {
                params: ArrayList(FnParameter) = .empty,

                pub fn parse(parser: *Parser, allocator: Allocator) !@This() {
                    _ = parser; // autofix
                    _ = allocator; // autofix
                }

                pub const FnParameter = struct {
                    name: Token,
                    @",": ?Token = null,

                    pub fn parse(parser: *Parser, allocator: Allocator) !@This() {
                        const name = try parser.lookaheadExpectOrHandleErrorAndSync(
                            allocator,
                            .{Token.Tag.identifier},
                            1,
                        ) orelse return null;
                        const @"," = try parser.lookaheadExpectOrHandleErrorAndSync(
                            allocator,
                            .{Token.Tag.@","},
                            1,
                        );

                        return .{
                            .name = name,
                            .@"," = @",",
                        };
                    }
                };
            };
        };
    };
};
