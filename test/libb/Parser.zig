const std = @import("std");
const testing = std.testing;
const allocator = testing.allocator;

const libb = @import("libb");
const Tokenizer = libb.Tokenizer;
const Parser = libb.Parser;
const Program = Parser.Program;
const Definition = Program.Definition;
const FnDefinition = Definition.FnDefinition;
const VarDefinition = Definition.VarDefinition;
const FnParameters = FnDefinition.FnParameters;
const FnParameter = FnParameters.FnParameter;

test FnParameter {
    const input = "i";
    const expected: FnParameter = .{
        .name = .{
            .tag = .identifier,
            .value = "i",
            .span = .{ .begin = 0, .end = 1 },
        },
    };

    var tokenizer: Tokenizer = .init(input);

    var parser: Parser = .init(tokenizer);
    defer parser.deinit(allocator);
    var fn_parameter: FnParameter = try .parse(parser, allocator);
}
