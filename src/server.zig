const std = @import("std");

// Listen in local adress and 4000
// Use 0,0,0,0 for public adress
const port: u16 = 4000;
const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, port);

const User = struct {
    allocator: std.mem.Allocator,
    stream: std.net.Stream,
    ip: std.net.Address,
    nickname: []const u8,
    fn create(allocator: std.mem.Allocator, connection: *std.net.StreamServer.Connection, nickname: ?[]const u8) !*User {
        const data = try allocator.create(User);
        data.allocator = allocator;
        data.stream = connection.stream;
        data.ip = connection.address;
        data.nickname = nickname.?;
        return data;
    }
    fn destroy(self: *User) void {
        self.allocator.destroy(self);
        // self.* = undefined;
    }
};

fn handle_connection(user: *User) void {
    defer user.stream.close();

    std.debug.print("New Connection: {}\n", .{user.ip});

    handle_stream_wrapper(&user.stream);
}

fn handle_stream_wrapper(stream: *std.net.Stream) void {
    handle_stream(stream) catch |err| {
        std.debug.print("An Error happened while handling_stream: {any}\n", .{err});
        return;
    };
}

fn handle_stream(stream: *std.net.Stream) !void {
    _ = try stream.write("Hello!\n");

    // Connection loop
    var buffer: [1024]u8 = undefined;
    while (true) {
        const bytes_read = stream.read(&buffer) catch |err| {
            std.debug.print("Read error :{any}\n", .{err});
            return;
        };
        std.debug.print("New message: {s}\n", .{buffer[0..bytes_read]});
    }
}

fn broadcast() void {
    return;
}

fn login(connection: *std.net.StreamServer.Connection) !*User {
    var stream = connection.stream;
    var buffer: [24]u8 = undefined;
    while (true) {
        try stream.writeAll("Please enter a username between 2 and 24 characters\n");

        @memset(buffer[0..], 0);

        const bytes_read = try stream.read(&buffer);
        if (bytes_read < 2 or bytes_read > 24) {
            // Repeat the cycle again
            try stream.writeAll("Invalid input. Please try again.\n");
            continue;
        }

        var user = try User.create(std.heap.page_allocator, connection, buffer[0..bytes_read]);
        return user;
    }
}

pub fn main() !void {

    // initialize the threadpool
    var pool: std.Thread.Pool = undefined;

    _ = try pool.init(.{ .allocator = std.heap.page_allocator }); // Init pool with page_allocator.
    defer pool.deinit();

    // Accept 16 User requests at the same time.
    // Reuse port and address after it
    const server_config = std.net.StreamServer.Options{ .reuse_address = true, .reuse_port = true, .kernel_backlog = 16 };

    var server = std.net.StreamServer.init(server_config);
    // Stop listening and deinit after main function
    defer server.deinit();
    defer server.close();

    _ = try server.listen(address);
    std.debug.print("Listening at {}\n", .{address});

    while (true) {
        // Accepting the connection
        var connection = server.accept() catch |err| {
            // You can just use try instead of catch
            std.debug.print("Some error happened while accepting the connection {any}\n", .{err});
            return;
        };

        var user = try login(&connection);

        _ = try pool.spawn(handle_connection, .{user});
    }
}
