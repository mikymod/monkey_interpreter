const std = @import("std");
const token = @import("token.zig");
const Token = token.Token;
const lookupIdent = token.lookupIdent;
const Allocator = std.mem.Allocator;

input: []const u8,
position: usize = 0,
read_position: usize = 1,
ch: u8 = 0,

const Self = @This();

pub fn init(input: []const u8) Self {
    var l = Self{
        .input = input,
        .position = 0,
        .read_position = 0,
        .ch = 0,
    };
    l.readChar();
    return l;
}

///
pub fn readChar(self: *Self) void {
    if (self.read_position >= self.input.len) {
        self.ch = 0;
        return;
    } else {
        self.ch = self.input[self.read_position];
    }
    self.position = self.read_position;
    self.read_position += 1;
}

///
pub fn peekChar(self: *Self) u8 {
    if (self.read_position >= self.input.len) {
        return 0;
    } else {
        return self.input[self.read_position];
    }
}

///
pub fn readIdentifier(self: *Self) []const u8 {
    const pos = self.position;
    while (isLetter(self.ch)) {
        self.readChar();
    }
    return self.input[pos..self.position];
}

fn isLetter(ch: u8) bool {
    return 'a' <= ch and ch <= 'z' or 'A' <= ch and ch <= 'Z' or ch == '_';
}

fn skipWhitespace(self: *Self) void {
    while (self.ch == ' ' or self.ch == '\t' or self.ch == '\n' or self.ch == '\r') {
        self.readChar();
    }
}

fn readNumber(self: *Self) []const u8 {
    const pos = self.position;
    while (isDigit(self.ch)) {
        self.readChar();
    }
    return self.input[pos..self.position];
}

fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}

///
pub fn nextToken(self: *Self) Token {
    self.skipWhitespace();

    const tok: Token = switch (self.ch) {
        '=' => blk: {
            if (self.peekChar() == '=') {
                self.readChar();
                break :blk Token.eq;
            }
            break :blk Token.assign;
        },
        '+' => Token.plus,
        '-' => Token.minus,
        '!' => blk: {
            if (self.peekChar() == '=') {
                self.readChar();
                break :blk Token.notEq;
            }
            break :blk Token.bang;
        },
        '/' => Token.slash,
        '*' => Token.asterisk,
        '<' => Token.lt,
        '>' => Token.gt,
        ';' => Token.semicolon,
        ',' => Token.comma,
        '(' => Token.lparen,
        ')' => Token.rparen,
        '{' => Token.lbrace,
        '}' => Token.rbrace,
        0 => Token.eof,
        else => {
            if (isLetter(self.ch)) {
                const ident = readIdentifier(self);
                return lookupIdent(ident);
            } else if (isDigit(self.ch)) {
                const num = readNumber(self);
                return token.Token{ .int = num };
            } else {
                return token.Token{ .illegal = self.ch };
            }
        },
    };

    self.readChar();
    return tok;
}

const t = std.testing;

fn expectIdent(expected: Token, actual: Token) !void {
    try t.expect(actual == .ident);
    try t.expectEqualStrings(expected.ident, actual.ident);
}

fn expectInt(expected: Token, actual: Token) !void {
    try t.expect(actual == .int);
    try t.expectEqualStrings(expected.int, actual.int);
}

test "Lexer - Next Token Simple" {
    const input = " =+(){},;";

    const tokens = [_]Token{
        Token.assign,
        Token.plus,
        Token.lparen,
        Token.rparen,
        Token.lbrace,
        Token.rbrace,
        Token.comma,
        Token.semicolon,
        Token.eof,
    };

    var l = init(input);

    for (tokens) |expected| {
        const actual = l.nextToken();
        try t.expectEqual(expected, actual);
    }
}

test "Lexer - Next Token Complex" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
        \\!-/*5;
        \\5 < 10 > 5;
        \\
        \\if (5 < 10) {
        \\  return true;
        \\} else {
        \\  return false;
        \\}
        \\
        \\10 == 10;
        \\10 != 9;
    ;

    const tokens = [_]Token{
        Token.let,
        Token{ .ident = "five" },
        Token.assign,
        Token{ .int = "5" },
        Token.semicolon,
        Token.let,
        Token{ .ident = "ten" },
        Token.assign,
        Token{ .int = "10" },
        Token.semicolon,
        Token.let,
        Token{ .ident = "add" },
        Token.assign,
        Token.function,
        Token.lparen,
        Token{ .ident = "x" },
        Token.comma,
        Token{ .ident = "y" },
        Token.rparen,
        Token.lbrace,
        Token{ .ident = "x" },
        Token.plus,
        Token{ .ident = "y" },
        Token.semicolon,
        Token.rbrace,
        Token.semicolon,
        Token.let,
        Token{ .ident = "result" },
        Token.assign,
        Token{ .ident = "add" },
        Token.lparen,
        Token{ .ident = "five" },
        Token.comma,
        Token{ .ident = "ten" },
        Token.rparen,
        Token.semicolon,
        Token.bang,
        Token.minus,
        Token.slash,
        Token.asterisk,
        Token{ .int = "5" },
        Token.semicolon,
        Token{ .int = "5" },
        Token.lt,
        Token{ .int = "10" },
        Token.gt,
        Token{ .int = "5" },
        Token.semicolon,
        Token.if_,
        Token.lparen,
        Token{ .int = "5" },
        Token.lt,
        Token{ .int = "10" },
        Token.rparen,
        Token.lbrace,
        Token.return_,
        Token.true_,
        Token.semicolon,
        Token.rbrace,
        Token.else_,
        Token.lbrace,
        Token.return_,
        Token.false_,
        Token.semicolon,
        Token.rbrace,
        Token{ .int = "10" },
        Token.eq,
        Token{ .int = "10" },
        Token.semicolon,
        Token{ .int = "10" },
        Token.notEq,
        Token{ .int = "9" },
        Token.semicolon,
        Token.eof,
    };

    var l = init(input);

    for (tokens) |expected| {
        const actual = l.nextToken();
        switch (expected) {
            Token.ident => try expectIdent(expected, actual),
            Token.int => try expectInt(expected, actual),
            else => try t.expectEqual(expected, actual),
        }
    }
}
