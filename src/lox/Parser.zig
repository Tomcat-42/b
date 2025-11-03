const std = @import("std");
const Io = std.Io;
const testing = std.testing;
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const util = @import("util");
const term = util.term;
const lox = @import("lox");
const Tokenizer = lox.Tokenizer;
const Token = Tokenizer.Token;

const Parser = @This();

pub const Error = struct {
    message: []const u8,
    span: Token.Span,
};

tokens: *Tokenizer,
errors: ArrayList(Error) = .empty,

pub fn init(tokens: *Tokenizer) Parser {
    return .{ .tokens = tokens };
}

pub fn deinit(this: *Parser, allocator: Allocator) void {
    this.errors.deinit(allocator);
}

pub fn parse(this: *Parser, allocator: Allocator) !?Expr {
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

inline fn expectOrHandleErrorAndSync(this: *Parser, allocator: Allocator, comptime expected: anytype) !?Token {
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

pub const Expr = union(enum) {
    literal_expr: *const LiteralExpr,
    unary_expr: *const UnaryExpr,
    bin_expr: *const BinExpr,
    group_expr: *const GroupExpr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const lookahead = try parser.tokens.peek() orelse return null;
        return switch (lookahead.tag) {
            .number,
            .string,
            .true,
            .false,
            .nil,
            => .{ .literal_expr = try LiteralExpr.parse(parser, allocator) orelse return null },
            .@"-",
            .@"!",
            => .{ .unary_expr = try UnaryExpr.parse(parser, allocator) orelse return null },
            .@"(" => .{ .group_expr = try GroupExpr.parse(parser, allocator) orelse return null },
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const LiteralExpr = union(enum) {
    number: Token,
    string: Token,
    true: Token,
    false: Token,
    nil: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const tok = try parser.expectOrHandleErrorAndSync(
            allocator,
            .{ .number, .string, .true, .false, .nil },
        ) orelse return null;

        return switch (tok.tag) {
            .number => .{ .number = tok },
            .string => .{ .string = tok },
            .true => .{ .true = tok },
            .false => .{ .false = tok },
            .nil => .{ .nil = tok },
            else => null,
        };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitLiteralExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const UnaryExpr = struct {
    op: *const UnaryOp,
    rhs: *const Expr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const op = try UnaryOp.parse(parser, allocator) orelse return null;
        const right = try Expr.parse(parser, allocator) orelse return null;

        return .{ .op = &op, .rhs = &right };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitUnaryExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const BinExpr = struct {
    lhs: *const Expr,
    op: *const BinOp,
    rhs: *const Expr,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const lhs = try Expr.parse(parser, allocator) orelse return null;
        const op = try BinOp.parse(parser, allocator) orelse return null;
        const rhs = try Expr.parse(parser, allocator) orelse return null;

        return .{ .lhs = lhs, .op = &op, .rhs = rhs };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitBinExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const GroupExpr = struct {
    @"(": Token,
    expr: *const Expr,
    @")": Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const @"(" = try parser.expectOrHandleErrorAndSync(allocator, .{.@"("}) orelse return null;
        const expr = try Expr.parse(parser, allocator) orelse return null;
        const @")" = try parser.expectOrHandleErrorAndSync(allocator, .{.@")"}) orelse return null;

        return .{ .@"(" = @"(", .expr = &expr, .@")" = @")" };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitGroupExpr(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const UnaryOp = struct {
    op: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const tok = try parser.expectOrHandleErrorAndSync(
            allocator,
            .{ .@"-", .@"!" },
        ) orelse return null;

        return .{ .op = tok };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitUnaryOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

pub const BinOp = struct {
    op: Token,

    pub fn parse(parser: *Parser, allocator: Allocator) !?@This() {
        const tok = try parser.expectOrHandleErrorAndSync(
            allocator,
            .{ .@"==", .@"!=", .@"<", .@"<=", .@">", .@">=", .@"+", .@"-", .@"*", .@"/" },
        ) orelse return null;

        return .{ .op = tok };
    }

    pub fn visit(this: *const @This(), visitor: Visitor) void {
        visitor.visitBinOp(this);
    }

    pub fn format(this: *const @This(), depth: usize) fmt.Alt(Format, Format.format) {
        return .{ .data = .{ .depth = depth, .data = this } };
    }

    const Format = MakeFormat(@This());
};

fn MakeFormat(T: type) type {
    return struct {
        depth: usize = 0,
        data: *const T,

        pub fn format(this: @This(), writer: *Io.Writer) Io.Writer.Error!void {
            const depth = this.depth;

            for (0..depth) |_| try writer.print(term.SEP, .{});
            try writer.print("{s}{s}{s}\n", .{ term.FG.BLUE, @typeName(T), term.RESET });

            switch (@typeInfo(T)) {
                .@"struct" => |s| inline for (s.fields) |field| switch (@typeInfo(field.type)) {
                    .pointer => |p| switch (p.size) {
                        .one => try writer.print("{f}", @field(this.data, field.name).format(depth + 1)),
                        else => for (@field(this.data, field.name)) |f| try writer.print("{f}", f.format(depth + 1)),
                    },
                    .optional => if (@field(this.data, field.name)) |f|
                        try writer.print("{f}", f.format(depth + 1)),
                    else => try writer.print("{f}", @field(this.data, field.name).format(depth + 1)),
                },
                .@"union" => |_| switch (this.data.*) {
                    inline else => |f| try writer.print("{f}", f.format(depth + 1)),
                },
                else => @compileError("MakeFormat only supports structs and tagged unions"),
            }
        }
    };
}

pub const Visitor = struct {
    ptr: *anyopaque,
    vtable: VTable,

    pub const VTable = struct {
        visitExpr: *const fn (this: *anyopaque, expr: *const Expr) void,
        visitLiteralExpr: *const fn (this: *anyopaque, expr: *const LiteralExpr) void,
        visitUnaryExpr: *const fn (this: *anyopaque, expr: *const UnaryExpr) void,
        visitBinExpr: *const fn (this: *anyopaque, expr: *const BinExpr) void,
        visitGroupExpr: *const fn (this: *anyopaque, expr: *const GroupExpr) void,
        visitUnaryOp: *const fn (this: *anyopaque, op: *const UnaryOp) void,
        visitBinOp: *const fn (this: *anyopaque, op: *const BinOp) void,
    };

    pub fn visitExpr(this: *Visitor, expr: *const Expr) void {
        this.vtable.visitExpr(this.ptr, expr);
    }

    pub fn visitLiteralExpr(this: *Visitor, expr: *const LiteralExpr) void {
        this.vtable.visitLiteralExpr(this.ptr, expr);
    }

    pub fn visitUnaryExpr(this: *Visitor, expr: *const UnaryExpr) void {
        this.vtable.visitUnaryExpr(this.ptr, expr);
    }

    pub fn visitBinExpr(this: *Visitor, expr: *const BinExpr) void {
        this.vtable.visitBinExpr(this.ptr, expr);
    }

    pub fn visitGroupExpr(this: *Visitor, expr: *const GroupExpr) void {
        this.vtable.visitGroupExpr(this.ptr, expr);
    }

    pub fn visitUnaryOp(this: *Visitor, op: *const UnaryOp) void {
        this.vtable.visitUnaryOp(this.ptr, op);
    }

    pub fn visitBinOp(this: *Visitor, op: *const BinOp) void {
        this.vtable.visitBinOp(this.ptr, op);
    }
};
