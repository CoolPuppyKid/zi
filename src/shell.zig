// purpose: setup the base for the shell
const std = @import("std");
const exit = @import("commands/exit.zig");
const cd = @import("commands/cd.zig");
const marker = @import("utils/marker.zig");
const config = @import("utils/config.zig");
const execute = @import("utils/execute.zig");
const help = @import("commands/help.zig");
const history = @import("utils/history.zig");
const interpreter = @import("interpreter/interpreter.zig");
const process = std.process;
const ArrayList = std.ArrayList;
const allocater = std.heap.page_allocator;

pub fn shell() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var args = std.process.args();
    var argsList = ArrayList([]const u8).init(allocater);
    defer argsList.deinit();

    while (args.next()) |arg| {
        try argsList.append(arg);
    }

    if (argsList.items.len >= 2) {
        if (try interpreter.runZiFile(argsList.items[1], allocater) > 0) {
            try stdout.print("following errors above occurred in file: {s}\n", .{argsList.items[1]});
        }
        try exit.exit();
    }

    try config.init(allocater);
    try history.initHistory(allocater);
    try marker.printShellMarker(allocater);
    while (true) {
        const input: []u8 = try stdin.readUntilDelimiterAlloc(allocater, '\n', 10000);
        defer allocater.free(input);

        if (input.len == 0) {
            try marker.printShellMarker(allocater);
            continue;
        }

        if (std.mem.eql(u8, input, "exit")) {
            // RELEASE ME
            try exit.exit();
        }

        if (std.mem.count(u8, input, "cd") > 0) {
            cd.cd(input, allocater, true) catch |err| {
                try stdout.print("Unknown Error: {}\n", .{err});
                try marker.printShellMarker(allocater);
            };
        } else if (std.mem.eql(u8, input, "help")) {
            try help.help(allocater);
        } else {
            execute.execute(input, allocater, true) catch {
                try stdout.print("Error most likely a invalid command\n", .{});
                try marker.printShellMarker(allocater);
            };
        }
    }
}
