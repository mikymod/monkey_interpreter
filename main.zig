const std = @import("std");
const repl = @import("repl.zig");

pub fn main() !void {
    // std.debug.print("Hello, world!\n", .{});
    try repl.start();
}
