const lexer = @import("lexer");
const Lexer = lexer.Lexer;
const Parser = @import("parser").Parser;
const expect = @import("std").testing.expect;

test "Parser" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\let foobar = 1000
    ;

    var l = Lexer{ .input = input };
    var parser = Parser{ .lexer = &l };

    _ = parser.parseProgram();
    // expect(program != null);
}
