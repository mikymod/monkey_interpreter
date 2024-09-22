const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("Lexer.zig");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ast = @import("ast.zig");
const Operator = ast.Operator;

const Self = @This();

allocator: Allocator,
lexer: *Lexer,
cur_token: Token = undefined,
peek_token: Token = undefined,
errors: std.ArrayList([]const u8),

const ParserError = error{
    ExpectExpression,
    ExpectIdentifier,
    ExpectInteger,
    InvalidProgram,
    InvalidInteger,
    InvalidPrefix,
    InvalidInfix,
    InvalidOperator,
    ExpectPeek,
    MemoryAllocation,
};

const ExprPrecedence = enum(u4) {
    lowest = 0,
    equals = 1,
    less_greater = 2,
    sum = 3,
    product = 4,
    prefix = 5,
    call = 6,

    fn fromToken(token: Token) ExprPrecedence {
        return switch (token) {
            Token.eq => .equals,
            Token.notEq => .equals,
            Token.lt => .less_greater,
            Token.gt => .less_greater,
            Token.plus => .sum,
            Token.minus => .sum,
            Token.slash => .product,
            Token.asterisk => .product,
            Token.lparen => .call,
            else => .lowest,
        };
    }
};

pub fn init(allocator: Allocator, lexer: *Lexer) Self {
    var parser = Self{
        .allocator = allocator,
        .lexer = lexer,
        .errors = std.ArrayList([]const u8).init(allocator),
    };

    parser.nextToken();
    parser.nextToken();

    return parser;
}

pub fn deinit(self: Self, program: ast.Program) void {
    program.deinit(self.allocator);
    self.errors.deinit();
}

pub fn nextToken(self: *Self) void {
    self.cur_token = self.peek_token;
    self.peek_token = self.lexer.nextToken();
}

pub fn parseProgram(self: *Self) !ast.Program {
    var statements = std.ArrayList(ast.Statement).init(self.allocator);

    while (self.cur_token != Token.eof) {
        const stmt = try self.parseStatement();
        try statements.append(stmt);
        self.nextToken();
    }

    return ast.Program{ .statements = statements };
}

pub fn parseStatement(self: *Self) !ast.Statement {
    switch (self.cur_token) {
        Token.let => {
            const letStmt = try self.parseLetStatement();
            return ast.Statement{ .let = letStmt };
        },
        Token.return_ => {
            const returnStmt = try self.parseReturnStatement();
            return ast.Statement{ .ret = returnStmt };
        },
        else => {
            const exprStmt = try self.parseExpressionStatement();
            return ast.Statement{ .expr = exprStmt };
        },
    }
}

pub fn parseLetStatement(self: *Self) !ast.LetStatement {
    const token = self.cur_token;

    try self.expectPeek(.ident);

    const name = switch (self.cur_token) {
        .ident => |ident| ast.Identifier{
            .token = self.cur_token,
            .value = ident,
        },
        else => unreachable,
    };

    try self.expectPeek(.assign);
    self.nextToken();

    const expression = try self.parseExpression(ExprPrecedence.lowest);
    if (self.peekTokenIs(.semicolon)) {
        self.nextToken();
    }

    return ast.LetStatement{
        .token = token,
        .name = name,
        .value = expression,
    };
}

pub fn parseReturnStatement(self: *Self) !ast.ReturnStatement {
    self.nextToken();

    const expression = try self.parseExpression(ExprPrecedence.lowest);
    if (self.peekTokenIs(.semicolon)) {
        self.nextToken();
    }

    return ast.ReturnStatement{
        .token = self.cur_token,
        .value = expression,
    };
}

pub fn parseExpressionStatement(self: *Self) !ast.ExpressionStatement {
    const expression = try self.parseExpression(ExprPrecedence.lowest);
    // Optional semicolon
    if (self.peekTokenIs(.semicolon)) {
        self.nextToken();
    }

    const expressionPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;

    expressionPtr.* = expression;

    return ast.ExpressionStatement{
        .token = self.cur_token,
        .expression = expressionPtr,
    };
}

pub fn parseExpression(self: *Self, precedence: ExprPrecedence) !ast.Expression {
    var expr = try self.parseExpressionByPrefix(self.cur_token);

    const peek_precedence = self.peekPrecedence();
    while (!self.peekTokenIs(.semicolon) and @intFromEnum(precedence) < @intFromEnum(peek_precedence)) {
        const exprPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;
        exprPtr.* = expr;

        expr = try self.parseExpressionByInfix(self.peek_token, exprPtr);
    }

    return expr;
}

fn parseIdentifier(self: Self) !ast.Identifier {
    return switch (self.cur_token) {
        .ident => |value| ast.Identifier{
            .token = self.cur_token,
            .value = value,
        },
        else => ParserError.ExpectIdentifier,
    };
}

fn parseIntegerLiteral(self: Self) !ast.IntegerLiteral {
    return switch (self.cur_token) {
        .int => |value| ast.IntegerLiteral{
            .token = self.cur_token,
            .value = std.fmt.parseInt(i64, value, 10) catch return ParserError.InvalidInteger,
        },
        else => ParserError.InvalidInteger,
    };
}

fn parsePrefixExpression(self: *Self) ParserError!ast.PrefixExpression {
    const token = self.cur_token;
    const operator = try getOperatorFromToken(token);

    self.nextToken();

    const expr = try self.parseExpression(ExprPrecedence.prefix);
    const exprPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;
    exprPtr.* = expr;

    return ast.PrefixExpression{
        .token = token,
        .operator = operator,
        .right = exprPtr,
    };
}

fn parseInfixExpression(self: *Self, left: *ast.Expression) ParserError!ast.InfixExpression {
    const token = self.cur_token;
    const operator = try getOperatorFromToken(self.cur_token);
    const precedence = self.currentPrecedence();

    self.nextToken();
    const right = try self.parseExpression(precedence);

    const rightPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;
    rightPtr.* = right;

    return ast.InfixExpression{
        .token = token,
        .left = left,
        .operator = operator,
        .right = rightPtr,
    };
}

pub fn parseExpressionByPrefix(self: *Self, token_type: TokenType) !ast.Expression {
    return switch (token_type) {
        .ident => ast.Expression{ .identifier = try self.parseIdentifier() },
        .int => ast.Expression{ .integer = try self.parseIntegerLiteral() },
        .minus, .bang => ast.Expression{ .prefix = try self.parsePrefixExpression() },
        else => ParserError.InvalidPrefix,
    };
}

pub fn parseExpressionByInfix(self: *Self, token_type: TokenType, left: *ast.Expression) !ast.Expression {
    return switch (token_type) {
        .plus,
        .minus,
        .asterisk,
        .slash,
        .eq,
        .notEq,
        .gt,
        .lt,
        => {
            self.nextToken();
            return ast.Expression{ .infix = try self.parseInfixExpression(left) };
        },
        else => ParserError.InvalidInfix,
    };
}

pub fn curTokenIs(self: Self, token_type: TokenType) bool {
    return self.cur_token == token_type;
}

pub fn peekTokenIs(self: Self, token_type: TokenType) bool {
    return self.peek_token == token_type;
}

pub fn expectPeek(self: *Self, token_type: TokenType) !void {
    // TODO: Manage multiple parse errors
    // A ParseError returns whenever an error is found so we can see only the first error.
    // expectPeek should returns a bool and stores errors.

    if (self.peekTokenIs(token_type)) {
        self.nextToken();
    } else {

        // const str = try std.fmt.allocPrint(
        //     self.allocator,
        //     "Error: Expected {s}, Found {s}\n",
        //     .{ token_type.name(), @tagName(self.peek_token) },
        // );
        // defer self.allocator.free(str);
        // try self.errors.append(str);
        std.debug.print(
            "Error: Expected {s}, Found {s}\n",
            .{ token_type.name(), @tagName(self.peek_token) },
        );
        return ParserError.ExpectPeek;
    }
}

pub fn peekPrecedence(self: Self) ExprPrecedence {
    return ExprPrecedence.fromToken(self.peek_token);
}

pub fn currentPrecedence(self: Self) ExprPrecedence {
    return ExprPrecedence.fromToken(self.cur_token);
}

pub fn getOperatorFromToken(token: Token) !Operator {
    return switch (token) {
        .assign => .assign,
        .asterisk => .asterisk,
        .bang => .bang,
        .eq => .eq,
        .gt => .gt,
        .lt => .lt,
        .minus => .minus,
        .notEq => .notEq,
        .plus => .plus,
        .slash => .slash,
        else => ParserError.InvalidOperator,
    };
}

const t = std.testing;

test "Program - Let statements" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\let foobar = 1000;
    ;

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.items.len == 3);
    try std.testing.expect(parser.errors.items.len == 0);

    for (program.statements.items) |stmt| {
        try std.testing.expect(stmt.let.token == Token.let);
    }
}

test "Program - Parser errors" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\let 2345235;
    ;

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = parser.parseProgram();

    try t.expectError(ParserError.ExpectPeek, program);
}

test "Parser - Return statement" {
    const input =
        \\return 5;
        \\return 10;
        \\return 993322;
    ;

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.items.len == 3);
}

test "Parser - Parse Identifier" {
    const input = "foobar;";

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.items.len == 1);

    try std.testing.expect(@TypeOf(program.statements.items[0].expr) == ast.ExpressionStatement);
}

test "Parser - Parse Integer Literal" {
    const input = "5;";

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.items.len == 1);

    try std.testing.expect(@TypeOf(program.statements.items[0].expr) == ast.ExpressionStatement);
    try std.testing.expect(@TypeOf(program.statements.items[0].expr.expression.*.integer) == ast.IntegerLiteral);
}

test "Parser - Parse Prefix Expression" {
    const input = "-5;";

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.items.len == 1);

    try std.testing.expect(@TypeOf(program.statements.items[0].expr) == ast.ExpressionStatement);
    try std.testing.expect(@TypeOf(program.statements.items[0].expr.expression.*.prefix) == ast.PrefixExpression);
}

test "Parser - Parse Infix Expression" {
    const input =
        \\5 + 5;
        \\5 - 5;
        \\5 * 5;
        \\5 / 5;
        \\5 > 5;
        \\5 < 5;
        \\5 == 5;
        \\5 != 5;
    ;

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.items.len == 8);
}
