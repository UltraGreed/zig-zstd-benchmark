const std = @import("std");

const Io = std.Io;
const Dir = Io.Dir;
const Writer = Io.Writer;
const Reader = Io.Reader;
const Timestamp = Io.Timestamp;

const path = Dir.path;
const time = std.time;
const Allocator = std.mem.Allocator;

const zstd = std.compress.zstd;
const Decompress = zstd.Decompress;

const czstd = @import("libzstd");

const KiB = 1024;

const MIN_LEVEL = -7;
const MAX_LEVEL = 19; // should be 22, but Zig does not support "ultra" compression

/// Decompress ZSTD compressed bytes to out n times with C Zstd and return total time elapsed in seconds
fn benchC(io: Io, compressed: []const u8, out: []u8, n: usize) !f64 {
    const start = Timestamp.now(io, .awake);

    for (0..n) |_| {
        _ = try czstd.decompress(out, out.len, compressed, compressed.len);
    }

    const elapsed_ns = Timestamp.untilNow(start, io, .awake).nanoseconds;
    return @as(f64, @floatFromInt(elapsed_ns)) / time.ns_per_s;
}

/// Decompress ZSTD compressed bytes to out n times with Zig Zstd and return total time elapsed in seconds
fn benchZig(io: Io, compressed: []const u8, out: []u8, n: usize) !f64 {
    const start = Timestamp.now(io, .awake);

    for (0..n) |_| {
        var writer: Writer = .fixed(out);
        var comp_reader: Reader = .fixed(compressed);
        var zstd_stream: Decompress = .init(&comp_reader, &.{}, .{});

        _ = try zstd_stream.reader.streamRemaining(&writer);
    }

    const elapsed_ns = Timestamp.untilNow(start, io, .awake).nanoseconds;
    return @as(f64, @floatFromInt(elapsed_ns)) / time.ns_per_s;
}

fn intStrLessThan(lhs: []const u8, rhs: []const u8) !bool {
    const left = try std.fmt.parseInt(i8, lhs, 10);
    const right = try std.fmt.parseInt(i8, rhs, 10);
    return left < right;
}

fn intStrLessThanNoFail(_: void, lhs: []const u8, rhs: []const u8) bool {
    // FIXME: I'm not sure it's right way to do things
    return intStrLessThan(lhs, rhs).?;
}

fn listSubdirs(io: Io, allocator: Allocator, dir: Dir) ![][]const u8 {
    var levels: std.ArrayList([]const u8) = .empty;
    var iter_level = dir.iterate();
    while (try iter_level.next(io)) |level| {
        if (level.kind == .directory)
            try levels.append(allocator, try std.fmt.allocPrint(allocator, "{s}", .{level.name}));
    }

    return levels.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const path_comp = "data/compressed";
    const path_raw = "data/raw";
    const path_csv = "out/runs.csv";
    const csv_header = "Language,Compression level,File,N runs,Total time";
    const n_repeat = 10;

    var comp_dir = try Dir.cwd().openDir(io, path_comp, .{ .iterate = true });
    defer comp_dir.close(io);

    var raw_dir = try Dir.cwd().openDir(io, path_raw, .{ .iterate = true });
    defer raw_dir.close(io);

    try Dir.cwd().createDirPath(io, path.dirname(path_csv).?);

    std.debug.print("Decompression started for {s}:\n", .{path_comp});

    const levels = try listSubdirs(io, gpa, comp_dir);
    defer {
        for (levels) |level| gpa.free(level);
        gpa.free(levels);
    }

    std.mem.sort([]const u8, levels, {}, intStrLessThanNoFail);

    const csv_file = try Dir.cwd().createFile(io, path_csv, .{ .truncate = true });
    defer csv_file.close(io);

    var csv_buffer: [1 * KiB]u8 = undefined;
    var csv_writer = csv_file.writer(io, &csv_buffer);

    try csv_writer.interface.print("{s}\n", .{csv_header});

    const start_ts = Timestamp.now(io, .awake);
    for (levels) |level| {
        var level_dir = try comp_dir.openDir(io, level, .{ .iterate = true });

        var iter_file = level_dir.iterate();
        while (try iter_file.next(io)) |file| {
            if (file.kind != .file or !std.mem.eql(u8, path.extension(file.name), ".zst"))
                continue;

            const orig_file_name = path.stem(file.name);
            const raw = try raw_dir.readFileAlloc(io, orig_file_name, gpa, .unlimited);
            defer gpa.free(raw);

            const compressed = try level_dir.readFileAlloc(io, file.name, gpa, .unlimited);
            defer gpa.free(compressed);

            const full_path_comp = try path.join(gpa, &.{ path_comp, level, file.name });
            defer gpa.free(full_path_comp);

            std.debug.print("Decompressing {s}:\n", .{full_path_comp});

            // Zig run
            const out_zig = try gpa.alloc(u8, raw.len + zstd.block_size_max + zstd.default_window_len);
            defer gpa.free(out_zig);
            const elapsed_zig = try benchZig(io, compressed, out_zig, n_repeat);

            if (!std.mem.eql(u8, out_zig[0..raw.len], raw)) {
                std.debug.print("ERROR: Decompression with Zig mismatched original data! Exiting...", .{});
                std.process.exit(1);
            }

            try csv_writer.interface.print("{s},{s},{s},{d},{d}\n", .{ "Zig", level, orig_file_name, n_repeat, elapsed_zig });

            std.debug.print(" * Done in Zig for average {d:.3}s!\n", .{elapsed_zig / @as(f64, @floatFromInt(n_repeat))});

            // C run
            const out_c = try gpa.alloc(u8, raw.len);
            defer gpa.free(out_c);
            const elapsed_c = try benchC(io, compressed, out_c, n_repeat); // TODO: bench streaming

            if (!std.mem.eql(u8, out_c, raw)) {
                std.debug.print("ERROR: Decompression with C mismatched original data! Exiting...", .{});
                std.process.exit(1);
            }

            try csv_writer.interface.print("{s},{s},{s},{d},{d}\n", .{ "C", level, orig_file_name, n_repeat, elapsed_c });

            std.debug.print(" * Done in C for average {d:.3}s!\n", .{elapsed_c / @as(f64, @floatFromInt(n_repeat))});
        }
        std.debug.print("\n", .{});
    }
    try csv_writer.interface.flush();

    const bench_ns = Timestamp.untilNow(start_ts, io, .awake).nanoseconds;
    std.debug.print("Benchmarking done in {d:.3}s!\n", .{@as(f64, @floatFromInt(bench_ns)) / time.ns_per_s});
}

test "C decompress" {
    const comp_path = "data/compressed/19/silesia.tar.zst";
    const raw_path = "data/raw/silesia.tar";

    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const comp = try Dir.cwd().readFileAlloc(io, comp_path, allocator, .unlimited);
    defer allocator.free(comp);

    const raw_size = czstd.getFrameContentSize(comp, comp.len);

    const decomp = try allocator.alloc(u8, raw_size);
    defer allocator.free(decomp);

    const decomp_bytes = try czstd.decompress(decomp, raw_size, comp, comp.len);

    try std.testing.expect(decomp_bytes == raw_size);

    const raw = try Dir.cwd().readFileAlloc(io, raw_path, allocator, .unlimited);
    defer allocator.free(raw);

    try std.testing.expect(std.mem.eql(u8, raw, decomp));
}
