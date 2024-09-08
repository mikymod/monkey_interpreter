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

pub fn init(allocator: Allocator, lexer: *Lexer) Self {
    var parser = Self{
        .allocator = allocator,
        .lexer = lexer,
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

    stmt.name = try self.allocator.create(ast.Identifier);
    errdefer {
        self.allocator.destroy(stmt.name);
        self.allocator.destroy(stmt);
    }
    stmt.name.* = .{ .token = self.cur_token, .value = self.cur_token.literal };

    while (self.cur_token.typez != Token.Type.SEMICOLON) {
        self.nextToken();
    }

    return stmt;
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

    for (program.statements) |stmt| {
        try std.testing.expect(stmt.let.token.typez == Token.Type.LET);
    }
}
