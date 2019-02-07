const index = @import("index.zig");
const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const math = std.math;
const debug = std.debug;

pub const Fs = struct {
    const Lookup = std.AutoHashMap([]const u8, usize);
    const Files = std.SegmentedList(FileData, 16);
    const FileData = std.ArrayList(u8);

    allocator: *mem.Allocator,
    files: Files,
    lookup: Lookup,

    pub fn init(allocator: *mem.Allocator) Fs {
        return Fs{
            .allocator = allocator,
            .files = Files.init(allocator),
            .lookup = Lookup.init(allocator),
        };
    }

    pub fn open(fs: *Fs, path: []const u8, flags: index.Open.Flags) !File {
        const data = if (fs.lookup.get(path)) |kv|
            fs.files.at(kv.value)
        else blk: {
            if ((flags & index.Open.Create) == 0)
                return error.NoFile;

            const i = fs.files.count();
            const path_copy = try mem.dupe(fs.allocator, u8, path);
            errdefer fs.allocator.free(path_copy);

            const res = try fs.files.addOne();
            res.* = FileData.init(fs.allocator);
            errdefer _ = fs.files.pop();

            _ = try fs.lookup.put(path_copy, i);
            break :blk res;
        };

        return File{
            .data =  data,
            .pos_ = 0,  
        };
    }

    pub fn close()
};


pub const File = struct {
    data: *Fs.FileData,
    pos_: usize,
    
    pub fn read(file: *File, buf: []u8) error{}![]u8 {
        const start = math.min(file.pos_, file.data.len);
        const len = math.min(buf.len, file.data.len - file.pos_);
        mem.copy(u8, buf[0..len], file.data.toSlice()[start..][0..len]);
        file.pos_ += len;
        return buf[0..len];
    }
    
    pub fn write(file: *File, buf: []const u8) !void {
        if (file.data.len < file.pos_ + buf.len) {
            const len = file.data.len;
            try file.data.resize(file.pos_ + buf.len);
            mem.set(u8, file.data.toSlice()[len..], 0);
        }
    
        mem.copy(u8, file.data.toSlice()[file.pos_..], buf);
        file.pos_ += buf.len;
    }

    pub fn seek(file: *File, p: u64) !void {
        file.pos_ = try math.cast(usize, p);
    }
    
    pub fn pos(file: *File) u64 {
        return file.pos_;
    }

    pub fn size(file: *File) u64 {
        return file.data.len;
    }
};

test "fs.mem" {
    var buf: [1000]u8 = undefined;
    var fba = heap.FixedBufferAllocator.init(&buf);
    var fs = Fs.init(&fba.allocator);

    {
        var file = try fs.open("test", index.Open.Create | index.Open.Write);
        try file.write("This is a test");
        debug.assertOrPanic(file.pos() == 14);
        debug.assertOrPanic(file.size() == 14);
        try file.seek(0);
        try file.write("sihT");
        debug.assertOrPanic(file.pos() == 4);
        debug.assertOrPanic(file.size() == 14);
        //try fs.close(file);
    }

    {
        var text_buf: [100]u8 = undefined;
        var file = try fs.open("test", index.Open.Read);
        const text = try file.read(&text_buf);
        debug.assertOrPanic(file.pos() == 14);
        debug.assertOrPanic(file.size() == 14);
        debug.assertOrPanic(mem.eql(u8, text, "sihT is a test"));
        //try fs.close(file);
    }
}
