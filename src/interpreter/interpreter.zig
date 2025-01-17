// purpose: provide critical functions for running .zi files
const std = @import("std");
const ArrayList = std.ArrayList;
const stdout = std.io.getStdOut().writer();
const cd = @import("../commands/cd.zig");
const exit = @import("../commands/exit.zig");
const execute = @import("../utils/execute.zig");
const marker = @import("../utils/marker.zig");
const file = @import("../utils/file.zig");

// the u8 is not a char it is return code
pub fn runZiFile(path: []const u8, allocater: std.mem.Allocator) !u8 {
    if (!try file.fileExists(path)) {
        try stdout.print("file does not exist", .{});
        return 1;
    }
    const ziFile = try file.fileReadAll(path, allocater);
    defer allocater.free(ziFile);

    var ziFileLines = std.mem.split(u8, ziFile, "\n");

    while (ziFileLines.next()) |line| {
        if (std.mem.count(u8, line, "exit") > 0) {
            try exit.exit();
        } else if (std.mem.count(u8, line, "cd") > 0) {
            cd.cd(@constCast(line), allocater, false) catch |err| {
                try stdout.print("command: cd returned: zi interpreter error: {}", .{err});
            };
        } else if (std.mem.count(u8, line, "@defaultPWD") > 0) {
            var tokens = std.mem.split(u8, line, " ");
            var tokenList = ArrayList([]const u8).init(allocater);
            defer tokenList.deinit();

            while (tokens.next()) |token| {
                try tokenList.append(token);
            }

            if (!std.mem.eql(u8, tokenList.items[1], "=")) {
                try stdout.print("zi interpreter error: expected = after {s}", .{tokenList.items[0]});
                return 1;
            }

            if (std.mem.count(u8, tokenList.items[2], "$") > 0) {
                const indexOfVarMarker: ?usize = std.mem.indexOf(u8, tokenList.items[2], "$");
                if (indexOfVarMarker == null) {
                    try stdout.print("zi interpreter error: im as clueless as you please make a github issue and attach the zi file", .{});
                    return 1;
                }
                const envVarKey = tokenList.items[2][indexOfVarMarker.? + 1 ..];
                const envVar = try std.process.getEnvVarOwned(allocater, envVarKey);
                try cd.setDefaultPWD(envVar);
            } else {
                try cd.setDefaultPWD(tokenList.items[2]);
            }
        } else if (std.mem.eql(u8, line, "")) {
            continue;
        } else {
            execute.execute(@constCast(line), allocater, false) catch |err| {
                try stdout.print("command: {s} returned: zi interpreter error: {}", .{ line, err });
            };
        }
    }

    return 0;
}
