// This project is a JIT-compiler for Soil binaries. Upon start, it parses the binary and compiles
// the byte code into x86_64 machine code instructions. It then jumps to those instructions. That
// causes the CPU hardware to directly execute the (translated) code written in Soil, without the
// overhead of an interpreter.

const std = @import("std");
const Alloc = std.mem.Allocator;
const ArrayList = std.ArrayList;
const compile = @import("compiler.zig").compile;
const MachineCode = @import("machine_code.zig");
const Vm = @import("vm.zig");
const Reg = @import("reg.zig").Reg;

const syscall_log = std.log.scoped(.syscall);

pub const std_options = .{ .log_scope_levels = &[_]std.log.ScopeLevel{
    .{ .scope = .syscall, .level = .warn },
} };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    var args = std.process.args();
    _ = args.next() orelse return error.NoProgramName;
    const binary_path = args.next() orelse return error.NoSoilBinary;
    var rest = ArrayList([]const u8).init(alloc);
    while (args.next()) |arg| try rest.append(arg);

    const binary = try std.fs.cwd().readFileAlloc(alloc, binary_path, 1000000000);
    var vm = try compile(alloc, binary, Syscalls);
    try vm.run();
}

const Syscalls = struct {
    pub fn exit(_: *Vm, status: i64) callconv(.C) void {
        syscall_log.info("exit({})\n", .{status});
        std.process.exit(@intCast(status));
    }

    pub fn print(vm: *Vm, msg_data: i64, msg_len: i64) callconv(.C) void {
        syscall_log.info("print({x}, {})\n", .{ msg_data, msg_len });
        const msg = vm.memory[@intCast(msg_data)..][0..@intCast(msg_len)];
        std.io.getStdOut().writer().print("{s}", .{msg}) catch {};
    }

    pub fn log(vm: *Vm, msg_data: i64, msg_len: i64) callconv(.C) void {
        syscall_log.info("log({x}, {})\n", .{ msg_data, msg_len });
        const msg = vm.memory[@intCast(msg_data)..][0..@intCast(msg_len)];
        std.io.getStdErr().writer().print("{s}", .{msg}) catch {};
    }

    pub fn create(vm: *Vm, filename_data: i64, filename_len: i64, mode: i64) callconv(.C) i64 {
        syscall_log.info("create({x}, {}, {o})\n", .{ filename_data, filename_len, mode });
        const filename = vm.memory[@intCast(filename_data)..][0..@intCast(filename_len)];
        const flags = .{ .ACCMODE = .RDWR, .CREAT = true, .TRUNC = true };
        const fd = std.os.linux.open(&(toCPath(filename) catch unreachable), flags, @intCast(mode));
        return @bitCast(fd);
    }

    pub fn open_reading(vm: *Vm, filename_data: i64, filename_len: i64) callconv(.C) i64 {
        syscall_log.info("open_reading({x}, {})\n", .{ filename_data, filename_len });
        const filename = vm.memory[@intCast(filename_data)..][0..@intCast(filename_len)];
        std.debug.print("opening {s}\n", .{filename});
        const flags = .{ .ACCMODE = .RDONLY };
        const fd = std.os.linux.open(&(toCPath(filename) catch unreachable), flags, 0);
        return @bitCast(fd);
    }

    pub fn open_writing(vm: *Vm, filename_data: i64, filename_len: i64) callconv(.C) i64 {
        syscall_log.info("open_writing({x}, {})\n", .{ filename_data, filename_len });
        const filename = vm.memory[@intCast(filename_data)..][0..@intCast(filename_len)];
        const flags = .{ .ACCMODE = .WRONLY, .TRUNC = true };
        const fd = std.os.linux.open(&(toCPath(filename) catch unreachable), flags, 0);
        return @bitCast(fd);
    }

    pub fn read(vm: *Vm, file_descriptor: i64, buffer_data: i64, buffer_len: i64) callconv(.C) i64 {
        syscall_log.info("read({}, {x}, {})\n", .{ file_descriptor, buffer_data, buffer_len });
        const fd: i32 = @intCast(file_descriptor);
        const len = std.os.linux.read(fd, vm.memory[@intCast(buffer_data)..].ptr, @intCast(buffer_len));
        return @bitCast(len);
    }

    pub fn write(vm: *Vm, file_descriptor: i64, buffer_data: i64, buffer_len: i64) callconv(.C) i64 {
        syscall_log.info("write({}, {x}, {})\n", .{ file_descriptor, buffer_data, buffer_len });
        const fd: i32 = @intCast(file_descriptor);
        const len = std.os.linux.write(fd, vm.memory[@intCast(buffer_data)..].ptr, @intCast(buffer_len));
        return @bitCast(len);
    }

    pub fn close(_: *Vm, file_descriptor: i64) callconv(.C) i64 {
        syscall_log.info("close({})\n", .{file_descriptor});
        const fd: i32 = @intCast(file_descriptor);
        return @bitCast(std.os.linux.close(fd));
    }

    pub fn argc(_: *Vm) callconv(.C) i64 {
        syscall_log.info("argc()\n", .{});
        var args = std.process.args();
        var count: i64 = 0;
        while (args.skip()) count += 1;
        return count - 1; // Skip the first arg, which is just the soil invocation.
    }

    pub fn arg(vm: *Vm, index: i64, buffer_data: i64, buffer_len: i64) callconv(.C) i64 {
        syscall_log.info("arg({}, {x}, {})\n", .{ index, buffer_data, buffer_len });
        var args = std.process.args();
        _ = args.skip(); // Skip the first arg, which is just the soil invocation.
        for (0..@intCast(index)) |_| _ = args.skip();
        const the_arg = args.next().?;
        const unsigned_buffer_len: usize = @intCast(buffer_len);
        const len: usize = @min(unsigned_buffer_len, the_arg.len);
        @memcpy(vm.memory[@intCast(buffer_data)..][0..len], the_arg[0..len]);
        return @intCast(len);
    }

    pub fn read_input(vm: *Vm, buffer_data: i64, buffer_len: i64) callconv(.C) i64 {
        syscall_log.info("read_input({x}, {})\n", .{ buffer_data, buffer_len });
        const len = std.io.getStdIn().reader().read(vm.memory[@intCast(buffer_data)..][0..@intCast(buffer_len)]) catch {
            std.log.err("Couldn't read from input.\n", .{});
            std.process.exit(1);
        };
        return @intCast(len);
    }

    pub fn execute(_: *Vm, binary_data: i64, binary_len: i64) callconv(.C) void {
        syscall_log.info("execute({x}, {})\n", .{ binary_data, binary_len });
        std.log.err("TODO: implement execute\n", .{});
        //   ; jmp .execute
        //   mov rax, r11 ; binary.len
        //   call malloc
        //   mov [binary], rax
        //   mov [binary.len], r11
        //   add r10, rbp
        // .copy_binary:
        //   cmp r11, 0
        //   je .clear_stack
        //   mov bl, [r10]
        //   mov [rax], bl
        //   inc r10
        //   inc rax
        //   dec r11
        //   jmp .copy_binary
        // .clear_stack:
        //   pop rax
        //   cmp rax, label_after_call_to_jit
        //   je .done_clearing_the_stack
        //   jmp .clear_stack
        // .done_clearing_the_stack:
        //   call compile_binary
        //   jmp run
    }
};

const PATH_MAX = std.os.linux.PATH_MAX;
pub fn toCPath(str: []const u8) ![PATH_MAX:0]u8 {
    var with_null: [PATH_MAX:0]u8 = undefined;
    @memcpy(with_null[0..str.len], str);
    with_null[str.len] = 0;
    return with_null;
}
