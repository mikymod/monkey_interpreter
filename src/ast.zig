const Token = @import("Token.zig");
const Allocator = @import("std").mem.Allocator;

///
pub const Node = struct {
    const Self = @This();

    ptr: *anyopaque,
    tokenLiteralFn: *const fn (*anyopaque) void,

    pub fn init(ptr: *anyopaque) Self {
        const Ptr = @TypeOf(ptr);
        const tmp = struct {
            pub fn tokenLiteral(p: *anyopaque) []const u8 {
                const self: Ptr = @ptrCast(@alignCast(p));
                return @call(.always_inline, @typeInfo(Ptr).Pointer.child.tokenLit, .{self});
            }
        };

        return .{
            .ptr = ptr,
            .tokenLiteralFn = tmp.tokenLiteral,
        };
    }

    pub fn tokenLit(self: *Node) []const u8 {
        return self.tokenLitFn(self.ptr);
    }
};

///
pub const Statement = union(enum) {
    program: *Program,
    let: *LetStatement,

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

pub const LetStatement = struct {
    token: Token,
    name: *Identifier,
    value: *Expression,

    pub fn node(self: *LetStatement) Node {
        return Node.init(self);
    }

    pub fn tokenLiteral(ls: *LetStatement) []const u8 {
        return ls.token.literal;
    }
};
