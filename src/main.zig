const repl = @import("repl.zig");
const Lexer = @import("Lexer.zig");

pub fn main() !void {
    try repl.start();
}
