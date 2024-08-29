const std = @import("std");

pub const Token = struct {
    typez: []const u8,
    literal: []const u8,
};

pub const ILLEGAL = "ILLEGAL";
pub const EOF = "EOF";
pub const IDENT = "IDENT";
pub const INT = "INT";

pub const ASSIGN = "=";
pub const PLUS = "+";
pub const MINUS = "-";
pub const BANG = "!";
pub const ASTERISK = "*";
pub const SLASH = "/";
pub const LT = "<";
pub const GT = ">";

pub const COMMA = ",";
pub const SEMICOLON = ";";
pub const LPAREN = "(";
pub const RPAREN = ")";
pub const LBRACE = "{";
pub const RBRACE = "}";
pub const FUNCTION = "FUNCTION";
pub const LET = "LET";

const keywords = [_][]const u8{
    "fn",
    "let",
};

pub fn lookupIdent(kw: []const u8) []const u8 {
    if (std.mem.eql(u8, kw, "fn")) {
        return FUNCTION;
    } else if (std.mem.eql(u8, kw, "let")) {
        return LET;
    }

    return IDENT;
}
