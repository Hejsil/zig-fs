pub const mem = @import("mem.zig");
pub const os = @import("os.zig");

const std = @import("std");
const heap = std.heap;
const debug = std.debug;
const testing = std.testing;

pub const Open = struct {
    pub const Flags = u8;

    pub const Create = 0b0001;
    pub const Truncate = 0b0010;
    pub const Read = 0b0100;
    pub const Write = 0b1000;
};

test "fs" {
    const backends = []type{
        mem.Fs,
        os.Fs,
    };
    debug.warn("\n");
    inline for (backends) |Fs| {
        var buf: [1000]u8 = undefined;
        var fba = heap.FixedBufferAllocator.init(&buf);
        var fs = switch (Fs) {
            mem.Fs => blk: {
                debug.warn("mem.Fs\n");
                break :blk Fs.init(&fba.allocator);
            },
            os.Fs => blk: {
                debug.warn("os.Fs\n");
                break :blk Fs.init();
            },
            else => comptime unreachable,
        };
        defer fs.deinit();

        const file_name = "zig-cache/test_output";
        {
            var file = try fs.open(file_name, Open.Create | Open.Write);
            try file.write("This is a test");
            testing.expectEqual(u64(14), try file.pos());
            testing.expectEqual(u64(14), try file.size());
            try file.seek(0);
            try file.write("sihT");
            testing.expectEqual(u64(4), try file.pos());
            testing.expectEqual(u64(14), try file.size());
            fs.close(&file);
        }

        {
            var text_buf: [100]u8 = undefined;
            var file = try fs.open(file_name, Open.Read);
            const text = try file.read(&text_buf);
            testing.expectEqual(u64(14), try file.pos());
            testing.expectEqual(u64(14), try file.size());
            testing.expectEqualSlices(u8, "sihT is a test", text);
            fs.close(&file);
        }
    }
}
