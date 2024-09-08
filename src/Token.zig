const std = @import("std");

typez: Type,
literal: []const u8,

pub const Type = enum {
    ILLEGAL,
    EOF,
    IDENT,
    INT,

    ASSIGN,
    PLUS,
    MINUS,
    BANG,
    ASTERISK,
    SLASH,
    LT,
    GT,
    EQ,
    NOT_EQ,

    COMMA,
    SEMICOLON,
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,

    FUNCTION,
    LET,
    TRUE,
    FALSE,
    IF,
    ELSE,
    RETURN,

    pub fn name(self: Type) []const u8 {
        return switch (self) {
            .ILLEGAL => "ILLEGAL",
            .EOF => "EOF",
            .IDENT => "IDENT",
            .INT => "INT",
            .ASSIGN => "ASSIGN",
            .PLUS => "PLUS",
            .MINUS => "MINUS",
            .BANG => "BANG",
            .ASTERISK => "ASTERISK",
            .SLASH => "SLASH",
            .LT => "LT",
            .GT => "GT",
            .EQ => "EQ",
            .NOT_EQ => "NOT_EQ",
            .COMMA => "COMMA",
            .SEMICOLON => "SEMICOLON",
            .LPAREN => "LPAREN",
            .RPAREN => "RPAREN",
            .LBRACE => "LBRACE",
            .RBRACE => "RBRACE",
            .FUNCTION => "FUNCTION",
            .LET => "LET",
            .TRUE => "TRUE",
            .FALSE => "FALSE",
            .IF => "IF",
            .ELSE => "ELSE",
            .RETURN => "RETURN",
        };
    }
};

const keywords = std.StaticStringMap(Type).initComptime([_]struct { []const u8, Type }{
    .{ "let", .LET },
    .{ "fn", .FUNCTION },
    .{ "if", .IF },
    .{ "else", .ELSE },
    .{ "return", .RETURN },
    .{ "true", .TRUE },
    .{ "false", .FALSE },
});

pub fn lookupIdent(kw: []const u8) Type {
    if (keywords.get(kw)) |ident| {
        return ident;
    }

    return Type.IDENT;
}
