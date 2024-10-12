const std = @import("std");
const Token = @import("token.zig").Token;
const Allocator = @import("std").mem.Allocator;
const String = @import("string.zig").String;

///
pub const Node = union(enum) {
    program: *Program,
    statement: *Statement,
    expression: *Expression,

    pub fn toString(self: Node, str: *String) !void {
        return switch (self.*) {
            .program => |p| p.toString(str),
            .statement => |s| s.toString(str),
            .expression => |s| s.toString(str),
        };
    }
};

///
pub const Statement = union(enum) {
    let: LetStatement,
    ret: ReturnStatement,
    expr: ExpressionStatement,
    block: BlockStatement,

    pub fn toString(self: Statement, str: *String) !void {
        return switch (self) {
            .let => |s| s.toString(str),
            .ret => |s| s.toString(str),
            .expr => |s| s.toString(str),
            .block => |s| s.toString(str),
        };
    }

    pub fn deinit(self: Statement, allocator: Allocator) void {
        switch (self) {
            .expr => |s| s.deinit(allocator),
            .block => |s| s.deinit(allocator),
            else => {},
        }
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

    pub fn toString(self: Expression, str: *String) !void {
        return switch (self) {
            .identifier => |ident| ident.toString(str),
            .integer => |integer| integer.toString(str),
            .boolean => |boolean| boolean.toString(str),
            .prefix => |prefix| prefix.toString(str),
            .infix => |infix| infix.toString(str),
            .if_ => |if_| if_.toString(str),
        };
    }

    pub fn deinit(self: Expression, allocator: Allocator) void {
        switch (self) {
            .prefix => |prefix| prefix.deinit(allocator),
            .infix => |infix| infix.deinit(allocator),
            .if_ => |if_| if_.deinit(allocator),
            else => {},
        }
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn toString(self: Identifier, str: *String) !void {
        try str.concat(self.value);
    }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),

    pub fn toString(self: Program, str: *String) !void {
        for (self.statements.items) |stmt| {
            try stmt.toString(str);
        }
    }

    pub fn deinit(self: Program, allocator: Allocator) void {
        for (self.statements.items) |stmt| {
            switch (stmt) {
                .expr => |expr_stmt| {
                    switch (expr_stmt.expression.*) {
                        .prefix => |prefix| prefix.deinit(allocator),
                        .infix => |infix| infix.deinit(allocator),
                        .if_ => |if_| if_.deinit(allocator),
                        else => {},
                    }

                    expr_stmt.deinit(allocator);
                },
                .block => |block| block.deinit(allocator),
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

    pub fn toString(self: LetStatement, str: *String) !void {
        try str.concat("let ");
        try self.name.toString(str);
        try str.concat(" = ");
        try self.value.toString(str);
        try str.concat(";");
    }
};

pub const ReturnStatement = struct {
    token: Token,
    value: Expression,

    pub fn toString(self: ReturnStatement, str: *String) !void {
        try str.concat("return ");
        try self.value.toString(str);
        try str.concat(";");
    }
};

pub const ExpressionStatement = struct {
    token: Token,
    expression: *Expression,

    pub fn toString(self: ExpressionStatement, str: *String) !void {
        try self.expression.toString(str);
    }

    pub fn deinit(self: ExpressionStatement, allocator: Allocator) void {
        self.expression.deinit(allocator);
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: i64,

    pub fn toString(self: IntegerLiteral, str: *String) !void {
        var buf: [16]u8 = undefined;
        const slice = try std.fmt.bufPrint(
            &buf,
            "{d}",
            .{self.value},
        );
        try str.concat(slice);
    }
};

pub const PrefixExpression = struct {
    token: Token,
    operator: Operator,
    right: *Expression,

    pub fn toString(self: PrefixExpression, str: *String) anyerror!void {
        try str.concat(self.operator.toString());
        try self.right.toString(str);
    }

    pub fn deinit(self: PrefixExpression, allocator: Allocator) void {
        self.right.deinit(allocator);
    }
};

pub const InfixExpression = struct {
    token: Token,
    left: *Expression,
    operator: Operator,
    right: *Expression,

    pub fn toString(self: InfixExpression, str: *String) !void {
        try self.left.toString(str);
        try str.concat(" ");
        try str.concat(self.operator.toString());
        try str.concat(" ");
        try self.right.toString(str);
    }

    pub fn deinit(self: InfixExpression, allocator: Allocator) void {
        self.left.deinit(allocator);
        self.right.deinit(allocator);
    }
};

pub const IfExpression = struct {
    token: Token,
    condition: *Expression,
    consequence: BlockStatement,
    alternative: ?BlockStatement,

    pub fn toString(self: IfExpression, str: *String) !void {
        try str.concat("if (");
        try self.condition.toString(str);
        try str.concat(") { ");
        try self.consequence.toString(str);
        try str.concat(" }");

        if (self.alternative != null) {
            try str.concat(" else { ");
            try self.alternative.?.toString(str);
            try str.concat(" }");
        }
    }

    pub fn deinit(self: IfExpression, allocator: Allocator) void {
        self.condition.deinit(allocator);
        self.consequence.deinit(allocator);
        if (self.alternative != null) {
            self.alternative.?.deinit(allocator);
        }
    }
};

pub const BlockStatement = struct {
    token: Token,
    statements: std.ArrayList(Statement),

    pub fn toString(self: BlockStatement, str: *String) !void {
        var i: usize = 0;
        while (i < self.statements.items.len) : (i += 1) {
            try self.statements.items[i].toString(str);
        }
    }

    pub fn deinit(self: BlockStatement, allocator: Allocator) void {
        for (self.statements.items) |stmt| {
            switch (stmt) {
                .expr => |expr_stmt| {
                    switch (expr_stmt.expression.*) {
                        .prefix => |prefix| prefix.deinit(allocator),
                        .infix => |infix| infix.deinit(allocator),
                        .if_ => |if_| if_.deinit(allocator),
                        else => {},
                    }

                    expr_stmt.deinit(allocator);
                },
                else => {},
            }
        }
    }
};

pub const BooleanLiteral = struct {
    token: Token,
    value: bool,

    pub fn toString(self: BooleanLiteral, str: *String) !void {
        try str.concat(if (self.value) "true" else "false");
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

    var str = String.init(t.allocator);
    defer str.deinit();
    try program.toString(&str);
    try t.expect(str.equal("let myVar = anotherVar;"));
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

    var str = String.init(t.allocator);
    defer str.deinit();
    try ifExpr.toString(&str);
    try t.expect(str.equal("if (x < y) { let foobar = 10; } else { return 0; }"));
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

    var str = String.init(t.allocator);
    defer str.deinit();
    try ifExpr.toString(&str);
    try t.expect(str.equal("if (x < y) { let foobar = 10; }"));
}
