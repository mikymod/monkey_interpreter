const std = @import("std");
const token = @import("token.zig");

pub const Lexer = struct {
    input: []const u8,
    position: usize,
    read_position: usize,
    ch: u8,

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
    pub fn readIdentifier(self: *Lexer) []const u8 {
        var pos = self.position;
        while (isLetter(self.ch)) {
            pos += 1;
            readChar(self);
        }
        return self.input[self.position..pos];
    }

    fn isLetter(ch: u8) bool {
        return 'a' <= ch and ch <= 'z' or 'A' <= ch and ch <= 'Z' or ch == '_';
    }

    ///
    pub fn nextToken(self: *Lexer) token.Token {
        const tok = switch (self.ch) {
            '=' => token.Token{ .typez = token.ASSIGN, .literal = "=" },
            ';' => token.Token{ .typez = token.SEMICOLON, .literal = ";" },
            '(' => token.Token{ .typez = token.LPAREN, .literal = "(" },
            ')' => token.Token{ .typez = token.RPAREN, .literal = ")" },
            ',' => token.Token{ .typez = token.COMMA, .literal = "," },
            '+' => token.Token{ .typez = token.PLUS, .literal = "+" },
            '{' => token.Token{ .typez = token.LBRACE, .literal = "{" },
            '}' => token.Token{ .typez = token.RBRACE, .literal = "}" },
            0 => token.Token{ .typez = token.EOF, .literal = "" },
            else => {
                if (isLetter(self.ch)) {
                    return token.Token{ .typez = token.IDENT, .literal = readIdentifier(self) };
                } else {
                    return token.Token{ .typez = token.ILLEGAL, .literal = "" };
                }
            },
        };

        readChar(self);
        return tok;
    }
};
