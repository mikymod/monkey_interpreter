const lexer = @import("lexer");
const Lexer = lexer.Lexer;
const Parser = @import("parser").Parser;
const expect = @import("std").testing.expect;
const Program = @import("parser").ast.Program;
const Statement = @import("parser").ast.Statement;

test "Parser" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\let foobar = 1000
    ;

    var l = Lexer{ .input = input };
    var parser = Parser{ .lexer = &l };

    const program = parser.parseProgram();
    expect(program != null);
    expect(program.?.statements.len == 3);
}
