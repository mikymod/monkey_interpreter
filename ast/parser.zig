const lexer = @import("lexer");
const Lexer = lexer.Lexer;
const Token = lexer.Token;
const Program = @import("ast.zig").Program;

pub const Parser = struct {
    lexer: *Lexer,
    cur_token: Token = undefined,
    peek_token: Token = undefined,

    pub fn nextToken(p: *Parser) void {
        p.cur_token = p.peek_token;
        p.peek_token = p.lexer.nextToken();
    }

    pub fn parseProgram(_: *Parser) ?Program {
        return null;
    }
};
