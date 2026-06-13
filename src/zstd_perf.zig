const std = @import("std");
const zstd = std.compress.zstd;

const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const Dir = std.Io.Dir;
const Timestamp = std.Io.Timestamp;

const czstd = @import("libzstd");

const embed_raw_path = "embed/silesia.tar";

const raw_data = @embedFile(embed_raw_path);
// This is optimized by compiler and not actually embedded in binary
const compressed_data = @embedFile(embed_raw_path ++ "_1.zst");  

fn benchZig(compressed: []const u8, out: []u8) !void {
    var writer: Writer = .fixed(out);
    var comp_reader: Reader = .fixed(compressed);
    var zstd_stream: zstd.Decompress = .init(&comp_reader, &.{}, .{});

    _ = try zstd_stream.reader.streamRemaining(&writer);
}

fn benchC(compressed: []const u8, out: []u8) !void {
    _ = try czstd.decompress(out, out.len, compressed, compressed.len);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len != 2) {
        std.debug.print("Usage: zstd_perf LANGUAGE\n", .{});
        std.process.exit(2);
    }

    const out = try gpa.alloc(u8, raw_data.len + zstd.block_size_max + zstd.default_window_len);
    defer gpa.free(out);

    const start_ts = Timestamp.now(io, .awake);
    if (std.mem.eql(u8, "c", args[1])) {
        try benchC(compressed_data, out);
    } else if (std.mem.eql(u8, "zig", args[1])) {
        try benchZig(compressed_data, out);
    } else {
        std.debug.print("Wrong language provided!\n", .{});
        std.process.exit(2);
    }
    const elapsed_ns = Timestamp.untilNow(start_ts, io, .awake).nanoseconds;
    std.debug.print("Done in {d:.2}s\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1e9});
}
