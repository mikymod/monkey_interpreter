const std = @import("std");

pub const TokenType = enum {
    illegal,
    eof,
    ident,
    int,

    assign,
    plus,
    minus,
    bang,
    asterisk,
    slash,
    lt,
    gt,
    eq,
    notEq,

    comma,
    semicolon,
    lparen,
    rparen,
    lbrace,
    rbrace,

    function,
    let,
    true_,
    false_,
    if_,
    else_,
    return_,

    // pub fn name(self: TokenType) []const u8 {
    //     return switch (self) {
    //         .illegal => "illegal",
    //         .eof => "eof",
    //         .ident => "ident",
    //         .int => "int",
    //         .assign => "assign",
    //         .plus => "plus",
    //         .minus => "minus",
    //         .bang => "bang",
    //         .asterisk => "asterisk",
    //         .slash => "slash",
    //         .lt => "lt",
    //         .gt => "gt",
    //         .eq => "eq",
    //         .notEq => "notEq",
    //         .comma => "comma",
    //         .semicolon => "semicolon",
    //         .lparen => "lparen",
    //         .rparen => "rparen",
    //         .lbrace => "lbrace",
    //         .rbrace => "rbrace",
    //         .function => "function",
    //         .let => "let",
    //         .true_ => "true_",
    //         .false_ => "false_",
    //         .if_ => "if_",
    //         .else_ => "else_",
    //         .return_ => "return_",
    //     };
    // }
};

pub const Token = union(TokenType) {
    illegal: u8,
    eof: void,

    ident: []const u8,
    int: []const u8,

    assign: void,
    plus: void,
    minus: void,
    bang: void,
    asterisk: void,
    slash: void,
    lt: void,
    gt: void,
    eq: void,
    notEq: void,

    comma: void,
    semicolon: void,
    lparen: void,
    rparen: void,
    lbrace: void,
    rbrace: void,

    function: void,
    let: void,
    true_: void,
    false_: void,
    if_: void,
    else_: void,
    return_: void,
};

const keywords = std.StaticStringMap(Token).initComptime([_]struct { []const u8, Token }{
    .{ "let", .let },
    .{ "fn", .function },
    .{ "if", .if_ },
    .{ "else", .else_ },
    .{ "return", .return_ },
    .{ "true", .true_ },
    .{ "false", .false_ },
});

pub fn lookupIdent(kw: []const u8) Token {
    if (keywords.get(kw)) |ident| {
        return ident;
    }

    return Token{ .ident = kw };
}
