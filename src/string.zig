const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const String = struct {
    buffer: std.ArrayList(u8),
    len: usize,

    pub fn init(allocator: Allocator) String {
        return String{
            .buffer = std.ArrayList(u8).init(allocator),
            .len = 0,
        };
    }

    pub fn deinit(self: *String) void {
        self.buffer.deinit();
    }

    /// Returns the capacity of the buffer.
    pub fn capacity(self: String) usize {
        return self.buffer.capacity;
    }

    /// Returns the length of the string.
    pub fn length(self: String) usize {
        return self.len;
    }

    /// Sets the string to the given literal.
    pub fn set(self: *String, literal: []const u8) !void {
        try self.buffer.insertSlice(0, literal);
        self.len = literal.len;
    }

    /// Returns true if the string is equal to the given literal. False otherwise.
    pub fn equal(self: String, literal: []const u8) bool {
        return mem.eql(u8, self.buffer.allocatedSlice()[0..self.len], literal);
    }

    /// Appends the given literal to the string.
    pub fn concat(self: *String, literal: []const u8) !void {
        try self.buffer.appendSlice(literal);
        self.len += literal.len;
    }
};

const t = std.testing;
test "String init" {
    var mut_str = String.init(t.allocator);
    defer mut_str.deinit();
    try t.expect(mut_str.capacity() == 0);

    var const_str = String.init(t.allocator);
    defer @constCast(&const_str).deinit();
    try t.expect(const_str.capacity() == 0);
}

test "String set" {
    var str = String.init(t.allocator);
    defer str.deinit();

    try t.expect(str.length() == 0);

    try str.set("Hello, Zig!");
    try t.expectEqual(str.length(), 11);

    try str.set("Hello");
    try t.expectEqual(str.length(), 5);
    try t.expect(str.equal("Hello"));

    try str.set("Lorem ipsum dolor sit amet, consectetur adipiscing elit");
    try t.expectEqual(str.length(), 55);
}

test "String concat" {
    var str = String.init(t.allocator);
    defer str.deinit();

    try str.set("Hello, ");
    try str.concat("World!");
    try t.expectEqual(str.length(), 13);
    try t.expect(str.equal("Hello, World!"));
}
