const std = @import("std");
const Token = @import("Token.zig");
const lookupIdent = Token.lookupIdent;
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
pub fn newToken(token_type: Token.Type, literal: []const u8) Token {
    return Token{ .typez = token_type, .literal = literal };
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

    const tok = switch (self.ch) {
        '=' => blk: {
            if (self.peekChar() == '=') {
                self.readChar();
                break :blk newToken(Token.Type.EQ, "==");
            }
            break :blk newToken(Token.Type.ASSIGN, "=");
        },
        '+' => newToken(Token.Type.PLUS, "+"),
        '-' => newToken(Token.Type.MINUS, "-"),
        '!' => blk: {
            if (self.peekChar() == '=') {
                self.readChar();
                break :blk newToken(Token.Type.NOT_EQ, "!=");
            }
            break :blk newToken(Token.Type.BANG, "!");
        },
        '/' => newToken(Token.Type.SLASH, "/"),
        '*' => newToken(Token.Type.ASTERISK, "*"),
        '<' => newToken(Token.Type.LT, "<"),
        '>' => newToken(Token.Type.GT, ">"),
        ';' => newToken(Token.Type.SEMICOLON, ";"),
        ',' => newToken(Token.Type.COMMA, ","),
        '(' => newToken(Token.Type.LPAREN, "("),
        ')' => newToken(Token.Type.RPAREN, ")"),
        '{' => newToken(Token.Type.LBRACE, "{"),
        '}' => newToken(Token.Type.RBRACE, "}"),
        0 => newToken(Token.Type.EOF, ""),
        else => {
            if (isLetter(self.ch)) {
                const ident = readIdentifier(self);
                const ident_type = lookupIdent(ident);
                return newToken(ident_type, ident);
            } else if (isDigit(self.ch)) {
                const num = readNumber(self);
                return newToken(Token.Type.INT, num);
            } else {
                return newToken(Token.Type.ILLEGAL, "");
            }
        },
    };

    self.readChar();
    return tok;
}

const expect = std.testing.expect;

test "Lexer - Next Token Simple" {
    const input = " =+(){},;";

    const tokens = [_]Token{
        Token{ .typez = Token.Type.ASSIGN, .literal = "=" },
        Token{ .typez = Token.Type.PLUS, .literal = "+" },
        Token{ .typez = Token.Type.LPAREN, .literal = "(" },
        Token{ .typez = Token.Type.RPAREN, .literal = ")" },
        Token{ .typez = Token.Type.LBRACE, .literal = "{" },
        Token{ .typez = Token.Type.RBRACE, .literal = "}" },
        Token{ .typez = Token.Type.COMMA, .literal = "," },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.EOF, .literal = "" },
    };

    var l = init(input);

    for (tokens) |t| {
        const tok = l.nextToken();
        try std.testing.expectEqualDeep(t, tok);
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
        Token{ .typez = Token.Type.LET, .literal = "let" },
        Token{ .typez = Token.Type.IDENT, .literal = "five" },
        Token{ .typez = Token.Type.ASSIGN, .literal = "=" },
        Token{ .typez = Token.Type.INT, .literal = "5" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.LET, .literal = "let" },
        Token{ .typez = Token.Type.IDENT, .literal = "ten" },
        Token{ .typez = Token.Type.ASSIGN, .literal = "=" },
        Token{ .typez = Token.Type.INT, .literal = "10" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.LET, .literal = "let" },
        Token{ .typez = Token.Type.IDENT, .literal = "add" },
        Token{ .typez = Token.Type.ASSIGN, .literal = "=" },
        Token{ .typez = Token.Type.FUNCTION, .literal = "fn" },
        Token{ .typez = Token.Type.LPAREN, .literal = "(" },
        Token{ .typez = Token.Type.IDENT, .literal = "x" },
        Token{ .typez = Token.Type.COMMA, .literal = "," },
        Token{ .typez = Token.Type.IDENT, .literal = "y" },
        Token{ .typez = Token.Type.RPAREN, .literal = ")" },
        Token{ .typez = Token.Type.LBRACE, .literal = "{" },
        Token{ .typez = Token.Type.IDENT, .literal = "x" },
        Token{ .typez = Token.Type.PLUS, .literal = "+" },
        Token{ .typez = Token.Type.IDENT, .literal = "y" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.RBRACE, .literal = "}" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.LET, .literal = "let" },
        Token{ .typez = Token.Type.IDENT, .literal = "result" },
        Token{ .typez = Token.Type.ASSIGN, .literal = "=" },
        Token{ .typez = Token.Type.IDENT, .literal = "add" },
        Token{ .typez = Token.Type.LPAREN, .literal = "(" },
        Token{ .typez = Token.Type.IDENT, .literal = "five" },
        Token{ .typez = Token.Type.COMMA, .literal = "," },
        Token{ .typez = Token.Type.IDENT, .literal = "ten" },
        Token{ .typez = Token.Type.RPAREN, .literal = ")" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.BANG, .literal = "!" },
        Token{ .typez = Token.Type.MINUS, .literal = "-" },
        Token{ .typez = Token.Type.SLASH, .literal = "/" },
        Token{ .typez = Token.Type.ASTERISK, .literal = "*" },
        Token{ .typez = Token.Type.INT, .literal = "5" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.INT, .literal = "5" },
        Token{ .typez = Token.Type.LT, .literal = "<" },
        Token{ .typez = Token.Type.INT, .literal = "10" },
        Token{ .typez = Token.Type.GT, .literal = ">" },
        Token{ .typez = Token.Type.INT, .literal = "5" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.IF, .literal = "if" },
        Token{ .typez = Token.Type.LPAREN, .literal = "(" },
        Token{ .typez = Token.Type.INT, .literal = "5" },
        Token{ .typez = Token.Type.LT, .literal = "<" },
        Token{ .typez = Token.Type.INT, .literal = "10" },
        Token{ .typez = Token.Type.RPAREN, .literal = ")" },
        Token{ .typez = Token.Type.LBRACE, .literal = "{" },
        Token{ .typez = Token.Type.RETURN, .literal = "return" },
        Token{ .typez = Token.Type.TRUE, .literal = "true" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.RBRACE, .literal = "}" },
        Token{ .typez = Token.Type.ELSE, .literal = "else" },
        Token{ .typez = Token.Type.LBRACE, .literal = "{" },
        Token{ .typez = Token.Type.RETURN, .literal = "return" },
        Token{ .typez = Token.Type.FALSE, .literal = "false" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.RBRACE, .literal = "}" },
        Token{ .typez = Token.Type.INT, .literal = "10" },
        Token{ .typez = Token.Type.EQ, .literal = "==" },
        Token{ .typez = Token.Type.INT, .literal = "10" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.INT, .literal = "10" },
        Token{ .typez = Token.Type.NOT_EQ, .literal = "!=" },
        Token{ .typez = Token.Type.INT, .literal = "9" },
        Token{ .typez = Token.Type.SEMICOLON, .literal = ";" },
        Token{ .typez = Token.Type.EOF, .literal = "" },
    };

    var l = init(input);

    for (tokens) |t| {
        const tok = l.nextToken();
        try std.testing.expectEqualDeep(t, tok);
    }
}
