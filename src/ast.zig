const std = @import("std");
const Token = @import("Token.zig");
const Allocator = @import("std").mem.Allocator;

///
pub const Node = union(enum) {
    program: *Program,
    statement: *Statement,
    expression: *Expression,

    pub fn toString(self: *Node, allocator: Allocator) []const u8 {
        return switch (self.*) {
            .program => |p| p.toString(allocator),
            .statement => |s| s.toString(allocator),
            .expression => |s| s.toString(allocator),
        };
    }
};

///
pub const Statement = union(enum) {
    let: *LetStatement,
    @"return": *ReturnStatement,
    expr: *ExpressionStatement,

    pub fn toString(self: *const Statement, allocator: Allocator) []const u8 {
        return switch (self.*) {
            .let => |s| s.toString(allocator),
            .@"return" => |s| s.toString(allocator),
            .expr => |s| s.toString(allocator),
        };
    }
};

///
pub const Expression = union(enum) {
    identifier: *Identifier,

    pub fn toString(self: *Expression, allocator: Allocator) []const u8 {
        return switch (self.*) {
            .identifier => |s| s.*.toString(allocator),
            // else => unreachable,
        };
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn tokenLiteral(self: *Identifier) []const u8 {
        return self.token.literal;
    }

    pub fn toString(self: *Identifier, _: Allocator) []const u8 {
        return self.value;
    }
};

pub const Program = struct {
    statements: []Statement,

    pub fn tokenLiteral(p: *Program) []const u8 {
        if (p.statements.len > 0) {
            return p.statements[0].tokenLiteral();
        }
        return "";
    }

    pub fn toString(self: *Program, allocator: Allocator) []const u8 {
        var buf = std.ArrayList(u8).initCapacity(allocator, 32) catch unreachable;
        defer buf.deinit();
        for (self.statements) |stmt| {
            const stmt_str = stmt.toString(allocator);
            defer allocator.free(stmt_str);
            buf.appendSlice(stmt_str) catch unreachable;
        }
        return buf.toOwnedSlice() catch unreachable;
    }
};

pub const LetStatement = struct {
    token: Token,
    name: *Identifier,
    value: *Expression,

    pub fn tokenLiteral(self: *LetStatement) []const u8 {
        return self.token.literal;
    }

    pub fn toString(self: *LetStatement, allocator: Allocator) []const u8 {
        return std.fmt.allocPrint(allocator, "{s} {s} = {s};", .{
            self.tokenLiteral(),
            self.name.tokenLiteral(),
            self.value.toString(allocator),
        }) catch unreachable;
    }
};

pub const ReturnStatement = struct {
    token: Token,
    value: *Expression,

    pub fn node(self: *ReturnStatement) Node {
        return Node.init(self);
    }

    pub fn tokenLiteral(self: *ReturnStatement) []const u8 {
        return self.token.literal;
    }

    pub fn toString(self: *ReturnStatement, allocator: Allocator) []const u8 {
        const str = self.value.toString(allocator);
        defer allocator.free(str);
        return std.fmt.allocPrint(allocator, "{s} {s};", .{ self.tokenLiteral(), str }) catch unreachable;
    }
};

pub const ExpressionStatement = struct {
    token: Token,
    expression: *Expression,

    pub fn tokenLiteral(self: *ExpressionStatement) []const u8 {
        return self.token.literal;
    }

    pub fn toString(self: *ExpressionStatement, allocator: Allocator) []const u8 {
        const str = self.expression.toString(allocator);
        return str;
    }
};

test "AST - toString" {
    // TODO: write test for toString
    var name_ident = Identifier{
        .token = Token{
            .typez = Token.Type.IDENT,
            .literal = "myVar",
        },
        .value = "myVar",
    };

    var value_ident = Identifier{
        .token = Token{
            .typez = Token.Type.IDENT,
            .literal = "anotherVar",
        },
        .value = "anotherVar",
    };

    var expr = Expression{ .identifier = &value_ident };

    var let = LetStatement{
        .token = Token{ .typez = Token.Type.LET, .literal = "let" },
        .name = &name_ident,
        .value = &expr,
    };

    var statements = [_]Statement{
        .{ .let = &let },
    };

    var program = Program{ .statements = &statements };

    try std.testing.expect(std.mem.eql(u8, program.toString(std.testing.allocator), "let myVar = anotherVar;"));
}
