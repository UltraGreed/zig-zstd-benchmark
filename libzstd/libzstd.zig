const cdef = @import("libzstd-ext.zig");
const std = @import("std");

pub fn decompress(dst: []u8, dstCapacity: usize, src: []const u8, compressedSize: usize) error{DecompressError}!usize {
    const res = cdef.ZSTD_decompress(@ptrCast(dst), dstCapacity, @ptrCast(src), compressedSize);
    if (isError(res)) 
        return error.DecompressError;  // HACK: This hides actual error code.
                                       // It'd be better to actually map errors from decompress, but this 
                                       // would require reimplementing getErrorCode function, as Zig does not
                                       // have @enumFromInt analogue for error unions.
    return res;
}

pub fn isError(result: usize) bool {
    return cdef.ZSTD_isError(result) != 0;
}

pub fn getErrorCode(functionResult: usize) usize {
    return cdef.ZSTD_getErrorCode(functionResult);
}

pub fn getFrameContentSize(src: []const u8, srcSize: usize) usize {
    return cdef.ZSTD_getFrameContentSize(@ptrCast(src), srcSize);
}
