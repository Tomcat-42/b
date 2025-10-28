const libb = @import("libb");
const Tokenizer = libb.Tokenizer;
const Token = Tokenizer.Token;

const std = @import("std");
const testing = std.testing;
const allocator = testing.allocator;
const expectEqualDeep = testing.expectEqualDeep;

test "parse comment: happy" {
    const input =
        \\/* Yes */
    ;

    const expected: []const Token = &.{.{
        .tag = .comment,
        .span = .{ .start = 2, .end = 7 },
        .value = " Yes ",
    }};

    var actual: Tokenizer = .init(input);
    var i: usize = 0;
    while (actual.next()) |a| : (i += 1) try expectEqualDeep(expected[i], a);

    try expectEqualDeep(actual.next(), null);
}

test "simple input" {
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

    var actual: Tokenizer = .init(input);
    var i: usize = 0;
    while (actual.next()) |t| : (i += 1) try expectEqualDeep(expected[i], t);
}
