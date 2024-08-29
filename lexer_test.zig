const std = @import("std");
const token = @import("token.zig");
const lexer = @import("lexer.zig");
const expect = std.testing.expect;

test "Next token simple input" {
    const input = "=+(){},;";

    const tokens = [_]token.Token{
        token.Token{ .typez = token.ASSIGN, .literal = "=" },
        token.Token{ .typez = token.PLUS, .literal = "+" },
        token.Token{ .typez = token.LPAREN, .literal = "(" },
        token.Token{ .typez = token.RPAREN, .literal = ")" },
        token.Token{ .typez = token.LBRACE, .literal = "{" },
        token.Token{ .typez = token.RBRACE, .literal = "}" },
        token.Token{ .typez = token.COMMA, .literal = "," },
        token.Token{ .typez = token.SEMICOLON, .literal = ";" },
        token.Token{ .typez = token.EOF, .literal = "" },
    };

    var l = lexer.Lexer{
        .input = input,
        .position = 0,
        .read_position = 0,
        .ch = 0,
    };
    l.readChar();

    for (tokens) |t| {
        const tok = try l.nextToken(std.testing.allocator);
        try expect(std.mem.eql(u8, t.typez, tok.typez));
        try expect(std.mem.eql(u8, t.literal, tok.literal));
        // std.debug.print("t: {s}, tok: {s}\n", .{ t.typez, tok.typez });
    }
}

test "Something more complex" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
    ;

    const tokens = [_]token.Token{
        token.Token{ .typez = token.LET, .literal = "let" },
        token.Token{ .typez = token.IDENT, .literal = "five" },
        token.Token{ .typez = token.ASSIGN, .literal = "=" },
        token.Token{ .typez = token.INT, .literal = "5" },
        token.Token{ .typez = token.SEMICOLON, .literal = ";" },
        token.Token{ .typez = token.LET, .literal = "let" },
        token.Token{ .typez = token.IDENT, .literal = "ten" },
        token.Token{ .typez = token.ASSIGN, .literal = "=" },
        token.Token{ .typez = token.INT, .literal = "10" },
        token.Token{ .typez = token.SEMICOLON, .literal = ";" },
        token.Token{ .typez = token.LET, .literal = "let" },
        token.Token{ .typez = token.IDENT, .literal = "add" },
        token.Token{ .typez = token.ASSIGN, .literal = "=" },
        token.Token{ .typez = token.FUNCTION, .literal = "fn" },
        token.Token{ .typez = token.LPAREN, .literal = "(" },
        token.Token{ .typez = token.IDENT, .literal = "x" },
        token.Token{ .typez = token.COMMA, .literal = "," },
        token.Token{ .typez = token.IDENT, .literal = "y" },
        token.Token{ .typez = token.RPAREN, .literal = ")" },
        token.Token{ .typez = token.LBRACE, .literal = "{" },
        token.Token{ .typez = token.IDENT, .literal = "x" },
        token.Token{ .typez = token.PLUS, .literal = "+" },
        token.Token{ .typez = token.IDENT, .literal = "y" },
        token.Token{ .typez = token.SEMICOLON, .literal = ";" },
        token.Token{ .typez = token.RBRACE, .literal = "}" },
        token.Token{ .typez = token.SEMICOLON, .literal = ";" },
        token.Token{ .typez = token.LET, .literal = "let" },
        token.Token{ .typez = token.IDENT, .literal = "result" },
        token.Token{ .typez = token.ASSIGN, .literal = "=" },
        token.Token{ .typez = token.IDENT, .literal = "add" },
        token.Token{ .typez = token.LPAREN, .literal = "(" },
        token.Token{ .typez = token.IDENT, .literal = "five" },
        token.Token{ .typez = token.COMMA, .literal = "," },
        token.Token{ .typez = token.IDENT, .literal = "ten" },
        token.Token{ .typez = token.RPAREN, .literal = ")" },
        token.Token{ .typez = token.SEMICOLON, .literal = ";" },
        token.Token{ .typez = token.EOF, .literal = "" },
    };

    var l = lexer.Lexer{
        .input = input,
        .position = 0,
        .read_position = 0,
        .ch = 0,
    };
    l.readChar();

    for (tokens) |t| {
        const tok = try l.nextToken(std.testing.allocator);
        try expect(std.mem.eql(u8, t.typez, tok.typez));
        try expect(std.mem.eql(u8, t.literal, tok.literal));
    }
}
