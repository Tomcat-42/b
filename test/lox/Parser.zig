const std = @import("std");
const testing = std.testing;
const expectEqualDeep = testing.expectEqualDeep;
const allocator = testing.allocator;

const lox = @import("lox");
const Tokenizer = lox.Tokenizer;
const Parser = lox.Parser;
const Expr = Parser.Expr;

test Expr {
    const expr: Expr = .{
        .bin_expr = &.{
            .lhs = &.{
                .literal_expr = &.{
                    .number = .{
                        .tag = .number,
                        .value = "1",
                    },
                },
            },
            .op = &.{
                .op = .{ .tag = .@"+", .value = "+" },
            },
            .rhs = &.{
                .literal_expr = &.{
                    .number = .{
                        .tag = .number,
                        .value = "2",
                    },
                },
            },
        },
    };

    std.debug.print("{f}\n", .{expr.format(0)});
}
