const index = @import("index.zig");
const builtin = @import("builtin");
const std = @import("std");
const os = std.os;

const is_posix = builtin.os != builtin.Os.windows;
const is_windows = builtin.os == builtin.Os.windows;

pub const Fs = struct {
    pub fn init() Fs {
        return Fs{};
    }

    pub fn deinit(fs: *Fs) void {}

    pub fn open(fs: *Fs, path: []const u8, flags: index.Open.Flags) !File {
        if (is_windows) {
            const path_w = try os.windows_util.sliceToPrefixedFileW(path);
            var desired_access: os.windows.DWORD = 0;
            var share_mode: os.windows.DWORD = 0;
            if ((flags | index.Open.Read) != 0) {
                desired_access |= os.windows.GENERIC_READ;
                share_mode |= os.windows.FILE_SHARE_READ;
            }
            if ((flags | index.Open.Write) != 0) {
                desired_access |= os.windows.GENERIC_WRITE;
                share_mode |= os.windows.FILE_SHARE_WRITE;
            }

            var creation_disposition: os.windows.DWORD = 0;
            if ((flags | index.Open.Create) != 0) {
                creation_disposition |= os.windows.OPEN_ALWAYS;
            } else {
                creation_disposition |= os.windows.OPEN_EXISTING;
            }
            if ((flags | index.Open.Truncate) != 0) {
                creation_disposition |= os.windows.TRUNCATE_EXISTING;
            }

            const handle = try os.windowsOpenW(
                path_w,
                desired_access,
                share_mode,
                creation_disposition,
                os.windows.FILE_ATTRIBUTE_NORMAL,
            );
            return File{ .handle = os.File.openHandle(handle) };
        } else if (is_posix) {
            const path_c = try os.toPosixPath(path);
            var linux_flags: u32 = os.posix.O_LARGEFILE;
            if ((flags | index.Open.Read) != 0 and (flags | index.Open.Write) != 0) {
                linux_flags |= os.posix.O_RDWR;
                linux_flags |= os.posix.O_CLOEXEC;
            } else if ((flags | index.Open.Read) != 0) {
                linux_flags |= os.posix.O_RDONLY;
            } else if ((flags | index.Open.Write) != 0) {
                linux_flags |= os.posix.O_WRONLY;
                linux_flags |= os.posix.O_CLOEXEC;
            }
            if ((flags | index.Open.Create) != 0)
                linux_flags |= os.posix.O_CREAT;
            if ((flags | index.Open.Truncate) != 0)
                linux_flags |= os.posix.O_TRUNC;

            const handle = try os.posixOpenC(&path_c, linux_flags, os.File.default_mode);
            return File{ .handle = os.File.openHandle(handle) };
        }
        @compileError("Unsupported OS");
    }

    pub fn close(fs: *Fs, file: *File) void {
        file.handle.close();
        file.* = undefined;
    }
};

pub const File = struct {
    handle: os.File,

    pub fn read(file: *File, buf: []u8) ![]u8 {
        const len = try file.handle.read(buf);
        return buf[0..len];
    }

    pub fn write(file: *File, buf: []const u8) !void {
        try file.handle.write(buf);
    }

    pub fn seek(file: *File, p: u64) !void {
        try file.handle.seekTo(@intCast(usize, p));
    }

    pub fn pos(file: *File) !u64 {
        return u64(try file.handle.getPos());
    }

    pub fn size(file: *File) !u64 {
        return u64(try file.handle.getEndPos());
    }
};
