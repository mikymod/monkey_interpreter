const std = @import("std");
const Token = @import("token.zig").Token;
const Allocator = @import("std").mem.Allocator;

///
pub const Node = union(enum) {
    program: *Program,
    statement: *Statement,
    expression: *Expression,

    pub fn toString(self: Node, allocator: Allocator) []const u8 {
        return switch (self.*) {
            .program => |p| p.toString(allocator),
            .statement => |s| s.toString(allocator),
            .expression => |s| s.toString(allocator),
        };
    }
};

///
pub const Statement = union(enum) {
    let: LetStatement,
    ret: ReturnStatement,
    expr: ExpressionStatement,

    pub fn toString(self: Statement, allocator: Allocator) []const u8 {
        return switch (self) {
            .let => |s| s.toString(allocator),
            .ret => |s| s.toString(allocator),
            .expr => |s| s.toString(allocator),
        };
    }
};

///
pub const Expression = union(enum) {
    identifier: Identifier,
    integer: IntegerLiteral,
    prefix: PrefixExpression,
    infix: InfixExpression,

    pub fn toString(self: Expression, allocator: Allocator) []const u8 {
        return switch (self) {
            .identifier => |s| s.toString(),
            .integer => |s| s.toString(allocator),
            .prefix => |s| s.toString(allocator),
            .infix => |s| s.toString(allocator),
        };
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn toString(self: Identifier) []const u8 {
        return self.value;
    }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),

    pub fn toString(self: Program, allocator: Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        var i: usize = 0;
        while (i < self.statements.items.len) : (i += 1) {
            const stmt = self.statements.items[i];
            const stmt_str = stmt.toString(allocator);
            defer allocator.free(stmt_str);
            try buf.appendSlice(stmt_str);
        }
        return buf.toOwnedSlice();
    }

    pub fn deinit(self: Program, allocator: Allocator) void {
        for (self.statements.items) |stmt| {
            switch (stmt) {
                .expr => |expr_stmt| {
                    std.debug.print("ExpressionStatement deinit.\n", .{});
                    switch (expr_stmt.expression.*) {
                        .prefix => |prefix| prefix.deinit(allocator),
                        .infix => |infix| infix.deinit(allocator),
                        .identifier => {},
                        .integer => {},
                    }

                    expr_stmt.deinit(allocator);
                },
                else => {},
            }
        }

        self.statements.deinit();
    }
};

pub const LetStatement = struct {
    token: Token,
    name: Identifier,
    value: Expression,

    pub fn toString(self: LetStatement, allocator: Allocator) []const u8 {
        return std.fmt.allocPrint(allocator, "{s} {s} = {s};", .{
            "let",
            self.name.toString(),
            self.value.toString(allocator),
        }) catch unreachable;
    }
};

pub const ReturnStatement = struct {
    token: Token,
    value: Expression,

    pub fn toString(self: ReturnStatement, allocator: Allocator) []const u8 {
        const str = self.value.toString(allocator);
        defer allocator.free(str);
        return std.fmt.allocPrint(
            allocator,
            "{s} {s};",
            .{ "return", str },
        ) catch unreachable;
    }
};

pub const ExpressionStatement = struct {
    token: Token,
    expression: *Expression,

    pub fn toString(self: ExpressionStatement, allocator: Allocator) []const u8 {
        const str = self.expression.toString(allocator);
        return str;
    }

    pub fn deinit(self: ExpressionStatement, allocator: Allocator) void {
        allocator.destroy(self.expression);
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: i64,

    pub fn toString(self: IntegerLiteral, allocator: Allocator) []const u8 {
        return std.fmt.allocPrint(
            allocator,
            "{d}",
            .{self.value},
        ) catch unreachable;
    }
};

pub const PrefixExpression = struct {
    token: Token,
    operator: Operator,
    right: *Expression,

    pub fn toString(self: PrefixExpression, allocator: Allocator) []const u8 {
        return std.fmt.allocPrint(allocator, "({s}{s})", .{
            self.operator.toString(),
            self.right.toString(allocator),
        }) catch unreachable;
    }

    pub fn deinit(self: PrefixExpression, allocator: Allocator) void {
        allocator.destroy(self.right);
    }
};

pub const InfixExpression = struct {
    token: Token,
    left: *Expression,
    operator: Operator,
    right: *Expression,

    pub fn toString(self: InfixExpression, allocator: Allocator) []const u8 {
        return std.fmt.allocPrint(allocator, "{s} {s} {s}", .{
            self.right.toString(allocator),
            self.operator.toString(),
            self.right.toString(allocator),
        }) catch unreachable;
    }

    pub fn deinit(self: InfixExpression, allocator: Allocator) void {
        allocator.destroy(self.left);
        allocator.destroy(self.right);
    }
};

pub const Operator = enum {
    assign,
    asterisk,
    bang,
    eq,
    gt,
    lt,
    minus,
    notEq,
    plus,
    slash,

    pub fn toString(self: Operator) []const u8 {
        return switch (self) {
            .assign => "=",
            .asterisk => "*",
            .bang => "!",
            .eq => "==",
            .gt => ">",
            .lt => "<",
            .minus => "-",
            .notEq => "!=",
            .plus => "+",
            .slash => "/",
        };
    }
};

const t = std.testing;

test "AST - toString" {
    const name_ident = Identifier{
        .token = Token{ .ident = "myVar" },
        .value = "myVar",
    };

    _ = &name_ident;

    const value_ident = Identifier{
        .token = Token{ .ident = "anotherVar" },
        .value = "anotherVar",
    };

    const expr = Expression{ .identifier = value_ident };

    var statements = std.ArrayList(Statement).init(t.allocator);
    defer statements.deinit();

    try statements.append(Statement{ .let = LetStatement{
        .token = Token.let,
        .name = name_ident,
        .value = expr,
    } });

    const program = Program{ .statements = statements };
    _ = &program;

    const str = try program.toString(t.allocator);
    try t.expect(
        std.mem.eql(
            u8,
            str,
            "let myVar = anotherVar;",
        ),
    );

    t.allocator.free(str);
}
