const Token = @import("../token.zig").Token;

const Node = union(enum) {
    statement: Statement,
    expression: Expression,

    pub fn tokenLiteral(_: Node) []const u8 {}
};

const Statement = struct {
    pub fn statementNode(_: Statement) void {}
};

const Expression = struct {
    pub fn expressionNode(_: Expression) void {}
};

const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn expressionNode() void {}
    pub fn tokenLiteral(i: Identifier) []const u8 {
        return i.token.literal;
    }
};

const Program = struct {
    statements: []Statement,

    pub fn tokenLiteral(p: Program) []const u8 {
        if (p.statements.len > 0) {
            return p.statements[0].tokenLiteral();
        } else {
            return "";
        }
    }
};

const LetStatement = struct {
    token: Token,
    name: Identifier,
    value: Expression,

    pub fn statementNode(_: LetStatement) void {}
    pub fn tokenLiteral(ls: LetStatement) void {
        return ls.token.literal;
    }
};
