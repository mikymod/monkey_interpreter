const Lexer = @import("../lexer/lexer.zig").Lexer;
const Parser = @import("../ast/parser.zig").Parser;
const expect = @import("std").testing.expect;

test "Parser" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\let foobar = 1000
    ;

    const lexer = Lexer{ .input = input };
    const parser = Parser{ .lexer = &lexer };

    const program = parser.parseProgram();
    expect(program != null);
}
