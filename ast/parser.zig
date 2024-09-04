const Lexer = @import("../lexer/lexer.zig").Lexer;
const Token = @import("../token.zig").Token;
const Program = @import("../ast/ast.zig").Program;

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
