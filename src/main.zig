const std = @import("std");
const httpz = @import("httpz");
const zmpl = @import("zmpl");

const file_util = @import("util/file_util.zig");

const RESOURCES_PATH = "resources/";

const Handler = struct {
    _resources_cache: *const std.StringHashMap([]const u8)
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var resources_cache = std.StringHashMap([]const u8).init(allocator);
    defer resources_cache.deinit();
    try load_cache(allocator, &resources_cache);

    std.log.info("Loaded {d} resources into the memory", .{ resources_cache.count() });

    var handler = Handler { ._resources_cache = &resources_cache };

    var server = try httpz.Server(*Handler).init(allocator, .{ .port = 5882 }, &handler);
    defer {
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.get("/", index, .{});
    router.get("/resources/*", resources, .{});

    try server.listen();
}

fn load_cache(allocator: std.mem.Allocator, storage: *std.StringHashMap([]const u8)) !void {
    var iterable_dir = try std.fs.cwd().openDir(RESOURCES_PATH, .{
        .iterate = true
    });

    var walker = try iterable_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if(entry.kind == std.fs.File.Kind.file) {
            const file_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ RESOURCES_PATH, entry.path });
            const file_data = try file_util.readFileAlloc(allocator, file_path);

            try storage.put(file_path, file_data);
        }
    }
}

fn index(_: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    if(zmpl.find("index")) |template| {
        var data = zmpl.Data.init(res.arena);
        defer data.deinit();

        res.status = 200;
        res.body = try template.render(&data, null, null, &.{}, .{});
        try res.write();
    }
}

fn resources(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const path = req.url.path;
    const cache_data = handler._resources_cache.get(path[1..]) orelse {
        res.status = 500;
        res.body = "no resource";
        return;
    };

    res.status = 200;
    res.body = cache_data;
}
