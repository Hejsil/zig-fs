const index = @import("index.zig");
const std = @import("std");
const mem = std.mem;
const math = std.math;

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

    pub fn deinit(fs: *Fs) void {
        var iter = fs.files.iterator(0);
        while (iter.next()) |data|
            data.deinit();

        var iter2 = fs.lookup.iterator();
        while (iter2.next()) |kv|
            fs.allocator.free(kv.key);

        fs.files.deinit();
        fs.lookup.deinit();
    }

    // TODO: Normalize path
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

        if ((flags & index.Open.Truncate) != 0)
            try data.resize(0);

        return File{
            .data = data,
            .flags = flags,
            .pos_ = 0,
        };
    }

    pub fn close(fs: *Fs, file: *File) void {
        file.* = undefined;
    }
};

pub const File = struct {
    data: *Fs.FileData,
    flags: index.Open.Flags,
    pos_: usize,

    pub fn read(file: *File, buf: []u8) ![]u8 {
        if ((file.flags & index.Open.Read) == 0)
            return error.FileCannotBeRead;

        const start = math.min(file.pos_, file.data.len);
        const len = math.min(buf.len, file.data.len - file.pos_);
        mem.copy(u8, buf[0..len], file.data.toSlice()[start..][0..len]);
        file.pos_ += len;
        return buf[0..len];
    }

    pub fn write(file: *File, buf: []const u8) !void {
        if ((file.flags & index.Open.Write) == 0)
            return error.FileCannotBeWritten;

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

    pub fn pos(file: *File) error{}!u64 {
        return u64(file.pos_);
    }

    pub fn size(file: *File) error{}!u64 {
        return u64(file.data.len);
    }
};
