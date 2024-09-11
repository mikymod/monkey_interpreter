const std = @import("std");
const Token = @import("Token.zig");
const Allocator = @import("std").mem.Allocator;

///
pub const Node = struct {
    const Self = @This();

    ptr: *anyopaque,
    tokenLiteralFn: *const fn (*anyopaque) []const u8,
    toStringFn: *const fn (*anyopaque, Allocator) []const u8,

    pub fn init(ptr: *anyopaque) Self {
        const Ptr = @TypeOf(ptr);
        const tmp = struct {
            pub fn tokenLiteral(p: *anyopaque) []const u8 {
                const self: Ptr = @ptrCast(@alignCast(p));
                return @call(.always_inline, @typeInfo(Ptr).Pointer.child.tokenLit, .{self});
            }

            pub fn toString(p: *anyopaque, allocator: Allocator) []const u8 {
                const self: Ptr = @ptrCast(@alignCast(p));
                return @call(.always_inline, @typeInfo(Ptr).Pointer.child.toString, .{ self, allocator });
            }
        };

        return .{
            .ptr = ptr,
            .tokenLiteralFn = tmp.tokenLiteral,
            .toStringFn = tmp.toString,
        };
    }

    pub fn tokenLiteral(self: *Node) []const u8 {
        return self.tokenLiteralFn(self.ptr);
    }

    pub fn toString(self: *Node, allocator: Allocator) []const u8 {
        return self.toStringFn(self.ptr, allocator);
    }
};

///
pub const Statement = union(enum) {
    program: *Program,
    let: *LetStatement,
    @"return": *ReturnStatement,
    expr: *ExpressionStatement,

    pub fn node(self: *Statement) Node {
        switch (self) {
            inline else => |case| case.node(),
        }
    }
};

///
pub const Expression = union(enum) {
    ident: *Identifier,

    pub fn node(self: *Expression) Node {
        switch (self) {
            inline else => |case| return case.node(),
        }
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn node(self: *Identifier) Node {
        return Node.init(self);
    }

    pub fn tokenLiteral(self: *Identifier) []const u8 {
        return self.token.literal;
    }
};

pub const Program = struct {
    statements: []Statement,

    pub fn init(self: *Program) Node {
        return Node.init(self);
    }

    pub fn tokenLiteral(p: *Program) []const u8 {
        if (p.statements.len > 0) {
            return p.statements[0].tokenLiteral();
        }
        return "";
    }

    pub fn toString(self: *Program, allocator: Allocator) []const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        for (self.statements) |stmt| {
            const stmt_str = stmt.node().toString(allocator);
            try buf.appendSlice(stmt_str);
            allocator.free(stmt_str);
        }
        return buf.toOwnedSlice();
    }
};

pub const LetStatement = struct {
    token: Token,
    name: *Identifier,
    value: *Expression,

    pub fn node(self: *LetStatement) Node {
        return Node.init(self);
    }

    pub fn tokenLiteral(self: *LetStatement) []const u8 {
        return self.token.literal;
    }

    pub fn toString(self: *LetStatement, allocator: Allocator) []const u8 {
        const value_str = self.value.node().toString(allocator);
        defer allocator.free(value_str);
        return try std.fmt.allocPrint(allocator, "{s} {s} = {s};", .{
            self.tokenLiteral(),
            self.name.tokenLiteral(),
            value_str,
        });
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
        const str = self.value.node().toString(allocator);
        defer allocator.free(str);
        return try std.fmt.allocPrint(allocator, "{s} {s};", .{ self.tokenLiteral(), str });
    }
};

pub const ExpressionStatement = struct {
    token: Token,
    expression: *Expression,

    pub fn node(self: *ExpressionStatement) Node {
        return Node.init(self);
    }

    pub fn tokenLiteral(self: *ExpressionStatement) []const u8 {
        return self.token.literal;
    }

    pub fn toString(self: *ExpressionStatement, allocator: Allocator) []const u8 {
        const str = self.expression.node().toString(allocator);
        return str;
    }
};

test "AST - toString" {
    // TODO: write test for toString
}
