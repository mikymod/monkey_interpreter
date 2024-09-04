const std = @import("std");
const repl = @import("repl.zig");
const Lexer = @import("lexer/lexer.zig").Lexer;
const Parser = @import("ast/parser.zig").Parser;

pub fn main() !void {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
    ;
    var lexer = Lexer{ .input = input };
    const parser = Parser{ .lexer = &lexer };
    _ = parser;
    // try repl.start();
}
