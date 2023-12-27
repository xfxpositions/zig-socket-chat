const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();
    var buffer: [1024]u8 = undefined;

    const result = try reader.readUntilDelimiterOrEof(&buffer, '\n');
    if (result) |value| {
        std.net.tcpConnectToAddress(value);
    }
}
