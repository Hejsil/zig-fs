pub const Open = struct {
    pub const Flags = u8;

    pub const Create = 0b0001;
    pub const Truncate = 0b0010;
    pub const Read = 0b0100;
    pub const Write = 0b1000;
};

pub const Fs = struct {
    pub fn open(fs: *Fs, path: []const u8, flags: Open.Flags) !*File {}
    pub fn close(fs: *Fs, file: *File) !void {}
};

pub const File = struct {
    pub fn read(file: *File, buf: []u8) ![]u8 {}
    pub fn write(file: *File, buf: []const u8) !void {}
    pub fn seek(file: *File, pos: u64) !void {}
    pub fn pos(file: *File) u64 {}
    pub fn size(file: *File) u64 {}
};

//test "" {
//    var fs: Fs = getFs();
//}
