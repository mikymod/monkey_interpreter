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

const ParserError = error{ ExpectExpression, ExpectIdentifier, ExpectPeek, MemoryAllocation };

const ExprPriority = enum(u4) {
    lowest = 0,
    equals = 1,
    less_greater = 2,
    sum = 3,
    product = 4,
    prefix = 5,
    call = 6,

    fn fromToken(token: Token) ExprPriority {
        return switch (token) {
            .EQ => .equals,
            .NOT_EQ => .equals,
            .LT => .less_greater,
            .GT => .less_greater,
            .PLUS => .sum,
            .MINUS => .sum,
            .SLASH => .product,
            .ASTERISK => .product,
            .LPAREN => .call,
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

pub fn parseStatement(self: *Self) ParserError!ast.Statement {
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

pub fn parseLetStatement(self: *Self) ParserError!ast.LetStatement {
    const token = self.cur_token;

    try self.expectPeek(Token.Type.IDENT);

    const name = ast.Identifier{
        .token = self.cur_token,
        .value = self.cur_token.literal,
    };

    try self.expectPeek(Token.Type.ASSIGN);
    self.nextToken();

    const expression = try self.parseExpression(ExprPriority.lowest);
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

    const expression = try self.parseExpression(ExprPriority.lowest);
    if (self.peekTokenIs(Token.Type.SEMICOLON)) {
        self.nextToken();
    }

    return ast.ReturnStatement{
        .token = self.cur_token,
        .value = expression,
    };
}

pub fn parseExpressionStatement(self: *Self) ParserError!ast.ExpressionStatement {
    const expression = try self.parseExpression(ExprPriority.lowest);
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

pub fn parseExpression(self: Self, _: ExprPriority) ParserError!ast.Expression {
    const left_exp = try self.parseExpressionByPrefix(self.cur_token);

    // TODO: parse infix expr

    return left_exp;
}

fn parseExpressionByPrefix(self: Self, token: Token) ParserError!ast.Expression {
    return switch (token.typez) {
        Token.Type.IDENT => ast.Expression{ .identifier = try self.parseIdentifier() },
        else => ParserError.ExpectExpression,
    };
}

fn parseIdentifier(self: Self) ParserError!ast.Identifier {
    return switch (self.cur_token.typez) {
        Token.Type.IDENT => ast.Identifier{
            .token = self.cur_token,
            .value = self.cur_token.literal,
        },
        else => ParserError.ExpectIdentifier,
    };
}

pub fn curTokenIs(self: Self, token_type: Token.Type) bool {
    return self.cur_token.typez == token_type;
}

pub fn peekTokenIs(self: Self, token_type: Token.Type) bool {
    return self.peek_token.typez == token_type;
}

pub fn expectPeek(self: *Self, token_type: Token.Type) ParserError!void {
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

    // TODO: type checking
}
