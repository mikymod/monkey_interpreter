const std = @import("std");
const token = @import("../token.zig");
const lookupIdent = token.lookupIdent;
const Allocator = std.mem.Allocator;

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,
    read_position: usize = 1,
    ch: u8 = 0,

    ///
    pub fn readChar(self: *Lexer) void {
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
    pub fn peekChar(self: *Lexer) u8 {
        if (self.read_position >= self.input.len) {
            return 0;
        } else {
            return self.input[self.read_position];
        }
    }

    ///
    pub fn readIdentifier(self: *Lexer, ident: []u8) usize {
        const pos = self.position;
        while (isLetter(self.ch)) {
            self.readChar();
        }
        std.mem.copyForwards(u8, ident, self.input[pos..self.position]);
        return self.position - pos;
    }

    fn isLetter(ch: u8) bool {
        return 'a' <= ch and ch <= 'z' or 'A' <= ch and ch <= 'Z' or ch == '_';
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.ch == ' ' or self.ch == '\t' or self.ch == '\n' or self.ch == '\r') {
            self.readChar();
        }
    }

    fn readNumber(self: *Lexer, num: []u8) usize {
        const pos = self.position;
        while (isDigit(self.ch)) {
            self.readChar();
        }
        std.mem.copyForwards(u8, num, self.input[pos..self.position]);
        return self.position - pos;
    }

    fn isDigit(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }

    ///
    pub fn nextToken(self: *Lexer) token.Token {
        self.skipWhitespace();
        const tok = switch (self.ch) {
            '=' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    break :blk token.Token{ .typez = token.EQ, .literal = "==" };
                }
                break :blk token.Token{ .typez = token.ASSIGN, .literal = "=" };
            },
            '+' => token.Token{ .typez = token.PLUS, .literal = "+" },
            '-' => token.Token{ .typez = token.MINUS, .literal = "-" },
            '!' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    break :blk token.Token{ .typez = token.NOT_EQ, .literal = "!=" };
                }
                break :blk token.Token{ .typez = token.BANG, .literal = "!" };
            },
            '/' => token.Token{ .typez = token.SLASH, .literal = "/" },
            '*' => token.Token{ .typez = token.ASTERISK, .literal = "*" },
            '<' => token.Token{ .typez = token.LT, .literal = "<" },
            '>' => token.Token{ .typez = token.GT, .literal = ">" },
            ';' => token.Token{ .typez = token.SEMICOLON, .literal = ";" },
            ',' => token.Token{ .typez = token.COMMA, .literal = "," },
            '(' => token.Token{ .typez = token.LPAREN, .literal = "(" },
            ')' => token.Token{ .typez = token.RPAREN, .literal = ")" },
            '{' => token.Token{ .typez = token.LBRACE, .literal = "{" },
            '}' => token.Token{ .typez = token.RBRACE, .literal = "}" },
            0 => token.Token{ .typez = token.EOF, .literal = "" },
            else => {
                var buffer: [10]u8 = [_]u8{0} ** 10;
                if (isLetter(self.ch)) {
                    const len = readIdentifier(self, &buffer);
                    const ident = buffer[0..len];
                    const ident_type = lookupIdent(ident);
                    return token.Token{ .typez = ident_type, .literal = ident };
                } else if (isDigit(self.ch)) {
                    const len = readNumber(self, &buffer);
                    const num = buffer[0..len];
                    return token.Token{ .typez = token.INT, .literal = num };
                } else {
                    return token.Token{ .typez = token.ILLEGAL, .literal = "" };
                }
            },
        };

        self.readChar();
        return tok;
    }
};
