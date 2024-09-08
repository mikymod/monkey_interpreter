const std = @import("std");
const Lexer = @import("Lexer.zig");

const PROMPT = ">> ";

pub fn start() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buffer: [1024]u8 = undefined;

    while (true) {
        try stdout.print("{s}", .{PROMPT});
        const line = try stdin.readUntilDelimiterOrEof(&buffer, '\r') orelse break;

        var l = Lexer.init(line);

        while (true) {
            const t = l.nextToken();
            if (std.mem.eql(u8, t.literal, "")) break;
            try stdout.print("{s}\n", .{t.literal});
            try stdout.print("{}\n", .{t.literal.len});
        }
    }
}
