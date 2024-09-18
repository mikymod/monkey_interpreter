const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("Lexer.zig");
const Token = @import("Token.zig");
const ast = @import("ast.zig");

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
    InvalidInteger,
    InvalidPrefix,
    InvalidInfix,
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
        return switch (token.typez) {
            Token.Type.EQ => .equals,
            Token.Type.NOT_EQ => .equals,
            Token.Type.LT => .less_greater,
            Token.Type.GT => .less_greater,
            Token.Type.PLUS => .sum,
            Token.Type.MINUS => .sum,
            Token.Type.SLASH => .product,
            Token.Type.ASTERISK => .product,
            Token.Type.LPAREN => .call,
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

pub fn deinit(self: Self, program: *ast.Program) void {
    _ = &self;
    _ = &program;
    // for (program.statements) |stmt| {
    //     switch (stmt) {
    //         .let => |s| {
    //             self.allocator.destroy(s.name);
    //             self.allocator.destroy(s);
    //         },
    //         .ret => |s| {
    //             self.allocator.destroy(s);
    //         },
    //         .expr => |_| {
    //             std.debug.print("ExpressionStatement deinit.\n", .{});
    //         },
    //     }
    // }
    // self.allocator.free(program.statements);
    // self.allocator.destroy(program);

    // for (self.errors.items) |err| {
    //     self.allocator.free(err);
    // }
    // self.errors.deinit();
}

pub fn nextToken(self: *Self) void {
    self.cur_token = self.peek_token;
    self.peek_token = self.lexer.nextToken();
}

pub fn parseProgram(self: *Self) !*ast.Program {
    const program = try self.allocator.create(ast.Program);
    errdefer self.allocator.destroy(program);

    var statements = std.ArrayList(ast.Statement).init(self.allocator);
    while (self.cur_token.typez != Token.Type.EOF) {
        const stmt = try self.parseStatement();
        try statements.append(stmt);
        self.nextToken();
    }

    program.statements = try statements.toOwnedSlice();
    return program;
}

pub fn parseStatement(self: *Self) !ast.Statement {
    switch (self.cur_token.typez) {
        Token.Type.LET => {
            const letStmt = try self.parseLetStatement();
            return ast.Statement{ .let = letStmt };
        },
        Token.Type.RETURN => {
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

    try self.expectPeek(Token.Type.IDENT);

    const name = ast.Identifier{
        .token = self.cur_token,
        .value = self.cur_token.literal,
    };

    try self.expectPeek(Token.Type.ASSIGN);
    self.nextToken();

    const expression = try self.parseExpression(ExprPrecedence.lowest);
    if (self.peekTokenIs(Token.Type.SEMICOLON)) {
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
    if (self.peekTokenIs(Token.Type.SEMICOLON)) {
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
    if (self.peekTokenIs(Token.Type.SEMICOLON)) {
        self.nextToken();
    }

    const expressionPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;

    expressionPtr.* = expression;

    return ast.ExpressionStatement{
        .token = self.cur_token,
        .expression = expressionPtr,
    };
}

pub fn parseExpression(self: *Self, precedence: ExprPrecedence) ParserError!ast.Expression {
    var expr = try self.parseExpressionByPrefix(self.cur_token);

    const peek_precedence = self.peekPrecedence();
    while (!self.peekTokenIs(Token.Type.SEMICOLON) and @intFromEnum(precedence) < @intFromEnum(peek_precedence)) {
        const exprPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;
        exprPtr.* = expr;

        expr = try self.parseExpressionByInfix(self.peek_token, exprPtr);
    }

    return expr;
}

fn parseIdentifier(self: Self) !ast.Identifier {
    return switch (self.cur_token.typez) {
        Token.Type.IDENT => ast.Identifier{
            .token = self.cur_token,
            .value = self.cur_token.literal,
        },
        else => ParserError.ExpectIdentifier,
    };
}

fn parseIntegerLiteral(self: Self) ParserError!ast.IntegerLiteral {
    return switch (self.cur_token.typez) {
        Token.Type.INT => ast.IntegerLiteral{
            .token = self.cur_token,
            .value = std.fmt.parseInt(i64, self.cur_token.literal, 10) catch return ParserError.InvalidInteger,
        },
        else => ParserError.InvalidInteger,
    };
}

fn parsePrefixExpression(self: *Self) ParserError!ast.PrefixExpression {
    const token = self.cur_token;

    self.nextToken();

    const expr = try self.parseExpression(ExprPrecedence.prefix);
    const exprPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;
    exprPtr.* = expr;

    return ast.PrefixExpression{
        .token = token,
        .operator = token.literal,
        .right = exprPtr,
    };
}

fn parseInfixExpression(self: *Self, left: *ast.Expression) ParserError!ast.InfixExpression {
    const token = self.cur_token;

    const precedence = self.currentPrecedence();
    self.nextToken();
    const right = try self.parseExpression(precedence);

    const rightPtr = self.allocator.create(ast.Expression) catch return ParserError.MemoryAllocation;
    rightPtr.* = right;

    return ast.InfixExpression{
        .token = token,
        .left = left,
        .operator = token.literal,
        .right = rightPtr,
    };
}

pub fn parseExpressionByPrefix(self: *Self, token: Token) ParserError!ast.Expression {
    return switch (token.typez) {
        Token.Type.IDENT => ast.Expression{ .identifier = try self.parseIdentifier() },
        Token.Type.INT => ast.Expression{ .integer = try self.parseIntegerLiteral() },
        Token.Type.MINUS, Token.Type.BANG => ast.Expression{ .prefix = try self.parsePrefixExpression() },
        else => ParserError.InvalidPrefix,
    };
}

pub fn parseExpressionByInfix(self: *Self, token: Token, left: *ast.Expression) !ast.Expression {
    return switch (token.typez) {
        Token.Type.PLUS,
        Token.Type.MINUS,
        Token.Type.ASTERISK,
        Token.Type.SLASH,
        Token.Type.EQ,
        Token.Type.NOT_EQ,
        Token.Type.GT,
        Token.Type.LT,
        => {
            self.nextToken();
            return ast.Expression{ .infix = try self.parseInfixExpression(left) };
        },
        else => ParserError.InvalidInfix,
    };
}

pub fn curTokenIs(self: Self, token_type: Token.Type) bool {
    return self.cur_token.typez == token_type;
}

pub fn peekTokenIs(self: Self, token_type: Token.Type) bool {
    return self.peek_token.typez == token_type;
}

pub fn expectPeek(self: *Self, token_type: Token.Type) !void {
    if (self.peekTokenIs(token_type)) {
        self.nextToken();
    } else {
        self.peekError(token_type);
        return ParserError.ExpectPeek;
    }
}

pub fn peekError(self: *Self, token_type: Token.Type) void {
    const err_str = std.fmt.allocPrint(
        self.allocator,
        "next token: expected {s}, got {s}.\n",
        .{
            token_type.name(),
            self.peek_token.typez.name(),
        },
    ) catch unreachable;

    self.errors.append(err_str) catch unreachable;
}

pub fn peekPrecedence(self: Self) ExprPrecedence {
    return ExprPrecedence.fromToken(self.peek_token);
}

pub fn currentPrecedence(self: Self) ExprPrecedence {
    return ExprPrecedence.fromToken(self.cur_token);
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

    try std.testing.expect(program.statements.len == 3);
    try std.testing.expect(parser.errors.items.len == 0);

    for (program.statements) |stmt| {
        try std.testing.expect(stmt.let.token.typez == Token.Type.LET);
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
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    std.debug.print("Parser has {} errors.\n", .{parser.errors.items.len});
    for (parser.errors.items) |err| {
        std.debug.print("{s}\n", .{err});
    }

    try std.testing.expect(parser.errors.items.len == 1);
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

    try std.testing.expect(program.statements.len == 3);
}

test "Parser - Parse Identifier" {
    const input = "foobar;";

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.len == 1);

    try std.testing.expect(@TypeOf(program.statements[0].expr) == ast.ExpressionStatement);
}

test "Parser - Parse Integer Literal" {
    const input = "5;";

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.len == 1);

    try std.testing.expect(@TypeOf(program.statements[0].expr) == ast.ExpressionStatement);
    try std.testing.expect(@TypeOf(program.statements[0].expr.expression.*.integer) == ast.IntegerLiteral);
}

test "Parser - Parse Prefix Expression" {
    const input = "-5;";

    var lexer = Lexer.init(input);
    var parser = init(t.allocator, &lexer);
    const program = try parser.parseProgram();
    defer parser.deinit(program);

    try std.testing.expect(program.statements.len == 1);

    try std.testing.expect(@TypeOf(program.statements[0].expr) == ast.ExpressionStatement);
    try std.testing.expect(@TypeOf(program.statements[0].expr.expression.*.prefix) == ast.PrefixExpression);
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

    try std.testing.expect(program.statements.len == 8);
}
