const std = @import("std");
const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const String = @import("string.zig").String;

const PROMPT = ">> ";

pub fn start() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buffer: [1024]u8 = undefined;

    while (true) {
        try stdout.print("{s}", .{PROMPT});
        const line = try stdin.readUntilDelimiterOrEof(&buffer, '\r') orelse break;

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var lexer = Lexer.init(line);
        var parser = Parser.init(allocator, &lexer);
        const program = try parser.parseProgram();

        var str = String.init(std.heap.page_allocator);
        defer str.deinit();
        try program.toString(&str);
        const slice = try str.buffer.toOwnedSlice();
        try stdout.print("{s}\n", .{slice});
    }
}
