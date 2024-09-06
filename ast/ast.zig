const Token = @import("lexer").Token;

pub const Node = union(enum) {
    statement: Statement,
    expression: Expression,

    pub fn tokenLiteral(_: *Node) []const u8 {}
};

pub const Statement = struct {
    pub fn statementNode(_: *Statement) void {}
};

pub const Expression = struct {
    pub fn expressionNode(_: *Expression) void {}
};

pub const Program = struct {
    statements: []Statement,

    pub fn tokenLiteral(p: *Program) []const u8 {
        if (p.statements.len > 0) {
            return p.statements[0].tokenLiteral();
        } else {
            return "";
        }
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn expressionNode(_: *Identifier) void {}
    pub fn tokenLiteral(i: *Identifier) []const u8 {
        return i.token.literal;
    }
};

pub const LetStatement = struct {
    token: Token,
    name: Identifier,
    value: Expression,

    pub fn statementNode(_: LetStatement) void {}
    pub fn tokenLiteral(ls: LetStatement) []const u8 {
        return ls.token.literal;
    }
};
