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
    block: BlockStatement,

    pub fn toString(self: Statement, allocator: Allocator) []const u8 {
        return switch (self) {
            .let => |s| s.toString(allocator),
            .ret => |s| s.toString(allocator),
            .expr => |s| s.toString(allocator),
            .block => |s| s.toString(allocator),
        };
    }
};

///
pub const Expression = union(enum) {
    identifier: Identifier,
    integer: IntegerLiteral,
    boolean: BooleanLiteral,
    prefix: PrefixExpression,
    infix: InfixExpression,
    if_: IfExpression,

    pub fn toString(self: Expression, allocator: Allocator) []const u8 {
        return switch (self) {
            .identifier => |ident| ident.toString(),
            .integer => |integer| integer.toString(allocator),
            .boolean => |boolean| boolean.toString(),
            .prefix => |prefix| prefix.toString(allocator),
            .infix => |infix| infix.toString(allocator),
            .if_ => |if_| if_.toString(allocator),
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
                    switch (expr_stmt.expression.*) {
                        .prefix => |prefix| prefix.deinit(allocator),
                        .infix => |infix| infix.deinit(allocator),
                        .identifier => {},
                        .integer => {},
                        .boolean => {},
                        .if_ => |if_| if_.deinit(allocator),
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
            self.left.toString(allocator),
            self.operator.toString(),
            self.right.toString(allocator),
        }) catch unreachable;
    }

    pub fn deinit(self: InfixExpression, allocator: Allocator) void {
        allocator.destroy(self.left);
        allocator.destroy(self.right);
    }
};

pub const IfExpression = struct {
    token: Token,
    condition: *Expression,
    consequence: BlockStatement,
    alternative: ?BlockStatement,

    pub fn toString(self: IfExpression, allocator: Allocator) []const u8 {
        var str = std.fmt.allocPrint(
            allocator,
            "if ({s}) {{ {s} }}",
            .{
                self.condition.toString(allocator),
                self.consequence.toString(allocator),
            },
        ) catch unreachable;

        if (self.alternative != null) {
            str = std.fmt.allocPrint(
                allocator,
                "{s} else {{ {s} }}",
                .{
                    str,
                    self.alternative.?.toString(allocator),
                },
            ) catch unreachable;
        }

        return str;
    }

    pub fn deinit(_: IfExpression, _: Allocator) void {
        // allocator.free(self.condition);
        // self.consequence.deinit(allocator);
        // self.alternative.deinit(allocator);
    }
};

pub const BlockStatement = struct {
    token: Token,
    statements: std.ArrayList(Statement),

    pub fn toString(self: BlockStatement, allocator: Allocator) []const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        var i: usize = 0;
        while (i < self.statements.items.len) : (i += 1) {
            const stmt = self.statements.items[i];
            const stmt_str = stmt.toString(allocator);
            // defer allocator.free(stmt_str);
            buf.appendSlice(stmt_str) catch unreachable;
        }
        return buf.toOwnedSlice() catch unreachable;
    }

    pub fn deinit(_: BlockStatement, _: Allocator) void {
        // for (self.statements.items) |stmt| {
        //     switch (stmt) {
        //         .expr => |expr_stmt| {
        //             std.debug.print("ExpressionStatement deinit.\n", .{});
        //             switch (expr_stmt.expression.*) {
        //                 .prefix => |prefix| prefix.deinit(allocator),
        //                 .infix => |infix| infix.deinit(allocator),
        //                 .identifier => {},
        //                 .integer => {},
        //                 .boolean => {},
        //                 .if_ => |if_| if_.deinit(allocator),
        //             }

        //             expr_stmt.deinit(allocator);
        //         },
        //         else => {},
        //     }
        // }

        // self.statements.deinit();
    }
};

pub const BooleanLiteral = struct {
    token: Token,
    value: bool,

    pub fn toString(self: BooleanLiteral) []const u8 {
        return if (self.value) "true" else "false";
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

test "IfExpression - toString()" {
    var left = Expression{
        .identifier = Identifier{
            .token = Token{ .ident = "x" },
            .value = "x",
        },
    };
    var right = Expression{
        .identifier = Identifier{
            .token = Token{ .ident = "y" },
            .value = "y",
        },
    };

    var consequences = std.ArrayList(Statement).init(t.allocator);
    defer consequences.deinit();
    try consequences.append(Statement{
        .let = LetStatement{
            .token = .let,
            .name = Identifier{
                .token = Token{ .ident = "foobar" },
                .value = "foobar",
            },
            .value = Expression{
                .integer = IntegerLiteral{
                    .token = Token{ .int = "10" },
                    .value = 10,
                },
            },
        },
    });
    var alternatives = std.ArrayList(Statement).init(t.allocator);
    defer alternatives.deinit();
    try alternatives.append(
        Statement{
            .ret = ReturnStatement{
                .token = .return_,
                .value = Expression{
                    .integer = IntegerLiteral{
                        .token = Token{ .int = "0" },
                        .value = 0,
                    },
                },
            },
        },
    );

    var condition = Expression{
        .infix = InfixExpression{
            .token = .lt,
            .left = &left,
            .operator = .lt,
            .right = &right,
        },
    };
    const ifExpr = IfExpression{
        .token = .if_,
        .condition = &condition,
        .consequence = BlockStatement{
            .token = .assign,
            .statements = consequences,
        },
        .alternative = BlockStatement{
            .token = .assign,
            .statements = alternatives,
        },
    };

    const str = ifExpr.toString(t.allocator);
    defer t.allocator.free(str);
    std.debug.print("{s}\n", .{str});
    try t.expect(std.mem.eql(
        u8,
        str,
        "if (x < y) { let foobar = 10; } else { return 0; }",
    ));
}

test "IfExpression - toString() w/o alternative" {
    var left = Expression{
        .identifier = Identifier{
            .token = Token{ .ident = "x" },
            .value = "x",
        },
    };
    var right = Expression{
        .identifier = Identifier{
            .token = Token{ .ident = "y" },
            .value = "y",
        },
    };

    var condition = Expression{
        .infix = InfixExpression{
            .token = .lt,
            .left = &left,
            .operator = .lt,
            .right = &right,
        },
    };
    var consequences = std.ArrayList(Statement).init(t.allocator);
    defer consequences.deinit();
    try consequences.append(Statement{
        .let = LetStatement{
            .token = .let,
            .name = Identifier{
                .token = Token{ .ident = "foobar" },
                .value = "foobar",
            },
            .value = Expression{
                .integer = IntegerLiteral{
                    .token = Token{ .int = "10" },
                    .value = 10,
                },
            },
        },
    });
    var alternatives = std.ArrayList(Statement).init(t.allocator);
    defer alternatives.deinit();

    const ifExpr = IfExpression{
        .token = .if_,
        .condition = &condition,
        .consequence = BlockStatement{
            .token = .assign,
            .statements = consequences,
        },
        .alternative = null,
    };

    const str = ifExpr.toString(t.allocator);
    std.debug.print("{s}\n", .{str});
    try t.expect(std.mem.eql(
        u8,
        str,
        "if (x < y) { let foobar = 10; }",
    ));
}
