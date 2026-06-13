const std = @import("std");
const time = std.time;

const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const Timestamp = std.Io.Timestamp;
const Dir = std.Io.Dir;

const zstd = std.compress.zstd;

const czstd = @import("libzstd");

const KiB = 1024;

fn benchZig(compressed: []const u8, out: []u8) !void {
    var writer: Writer = .fixed(out);
    var comp_reader: Reader = .fixed(compressed);
    var zstd_stream: zstd.Decompress = .init(&comp_reader, &.{}, .{});

    _ = try zstd_stream.reader.streamRemaining(&writer);
}

fn benchC(compressed: []const u8, out: []u8) !void {
    _ = try czstd.decompress(out, out.len, compressed, compressed.len);
}

const LibLanguage = enum {
    C,
    Zig,
};

fn parseLang(string: []const u8) !LibLanguage {
    if (std.mem.eql(u8, string, "c")) {
        return .C;
    } else if (std.mem.eql(u8, string, "zig")) {
        return .Zig;
    } else {
        return error.WrongArgument;
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len != 4) {
        std.debug.print("Usage: zstd_perf FILE_PATH LANGUAGE N\n", .{});
        std.process.exit(2);
    }

    const file_path = args[1];
    const language = parseLang(args[2]) catch {
        std.debug.print("Wrong language provided!\n", .{});
        std.process.exit(2);
    };
    const n_repeat = try std.fmt.parseInt(usize, args[3], 10);

    const compressed = try Dir.cwd().readFileAlloc(io, file_path, gpa, .unlimited);
    defer gpa.free(compressed);

    const decomp_size = czstd.getFrameContentSize(file_path, compressed.len);

    const out = try gpa.alloc(u8, decomp_size);
    defer gpa.free(out);

    const start_time = Timestamp.now(io, .awake);
    for (0..n_repeat) |_| {
        switch (language) {
            .C => try benchC(compressed, out),
            .Zig => try benchZig(compressed, out),
        }
    }

    const elapsed_ns = Timestamp.untilNow(start_time, io, .awake).nanoseconds;
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / time.ns_per_s;
    std.debug.print("Decompressed file {s} for {d} times with {s} in {d:.3}s!\n", .{ file_path, n_repeat, args[2], elapsed_s });
}
