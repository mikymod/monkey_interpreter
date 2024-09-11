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

pub fn deinit(self: *Self, program: *ast.Program) void {
    for (program.statements) |stmt| {
        switch (stmt) {
            .let => |s| {
                self.allocator.destroy(s.name);
                self.allocator.destroy(s);
            },
            else => unreachable,
        }
    }
    self.allocator.free(program.statements);
    self.allocator.destroy(program);

    for (self.errors.items) |err| {
        self.allocator.free(err);
    }
    self.errors.deinit();
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
        if (stmt != null) {
            try statements.append(stmt.?);
        }
        self.nextToken();
    }

    program.statements = try statements.toOwnedSlice();
    return program;
}

pub fn parseStatement(self: *Self) !?ast.Statement {
    switch (self.cur_token.typez) {
        Token.Type.LET => {
            const letStmt = try self.parseLetStatement();
            return .{ .let = letStmt orelse return null };
        },
        else => return null,
    }
}

pub fn parseLetStatement(self: *Self) !?*ast.LetStatement {
    var stmt = try self.allocator.create(ast.LetStatement);
    errdefer self.allocator.destroy(stmt);

    stmt.token = self.cur_token;

    if (!self.expectPeek(Token.Type.IDENT)) {
        return null;
    }

    stmt.name = try self.allocator.create(ast.Identifier);
    errdefer {
        self.allocator.destroy(stmt.name);
        self.allocator.destroy(stmt);
    }
    // FIXME: Error here
    if (!self.expectPeek(Token.Type.ASSIGN)) {
        return null;
    }

    stmt.name.* = .{ .token = self.cur_token, .value = self.cur_token.literal };

    while (!self.curTokenIs(Token.Type.SEMICOLON)) {
        self.nextToken();
    }

    return stmt;
}

pub fn curTokenIs(self: *Self, token_type: Token.Type) bool {
    return self.cur_token.typez == token_type;
}

pub fn peekTokenIs(self: *Self, token_type: Token.Type) bool {
    return self.peek_token.typez == token_type;
}

pub fn expectPeek(self: *Self, token_type: Token.Type) bool {
    if (self.peekTokenIs(token_type)) {
        self.nextToken();
        return true;
    }

    self.peekError(token_type);
    return false;
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
