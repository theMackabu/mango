const std = @import("std");
const config = @import("config");

const c = @cImport({
  @cInclude("stdio.h");
  @cInclude("crprintf.h");
});

pub const crprintf = c;

fn getStdout() *c.FILE { return c.stdout(); }
fn toCStr(s: []const u8) [*c]const u8 { return @ptrCast(s.ptr); }

pub fn printf(comptime fmt: [*:0]const u8, args: anytype) void {
  const prog = c.crprintf_compile(fmt) orelse return;
  defer c.crprintf_compiled_free(prog);

  const CArgs = comptime blk: {
    var fields: [args.len]std.builtin.Type.StructField = undefined;
    for (0..args.len) |i| {
      fields[i] = .{
        .name = std.fmt.comptimePrint("{d}", .{i}),
        .type = [*c]const u8,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf([*c]const u8),
      };
    }
    break :blk @Type(.{ .@"struct" = .{
      .layout = .auto,
      .fields = &fields,
      .decls = &.{},
      .is_tuple = true,
    }});
  };

  var c_args: CArgs = undefined;
  inline for (0..args.len) |i| c_args[i] = toCStr(args[i]);

  _ = @call(.auto, c.crprintf_exec, .{ prog, getStdout() } ++ c_args);
}

pub fn printVersion(allocator: std.mem.Allocator) !void {
  const build_time = config.build_timestamp;
  const now = std.time.timestamp();
  
  const age_seconds = now - build_time;
  const epoch_seconds = @as(u64, @intCast(build_time));
  
  const epoch_day = std.time.epoch.EpochDay{ .day = @divFloor(epoch_seconds, std.time.s_per_day) };
  const year_day = epoch_day.calculateYearDay(); 
  const month_day = year_day.calculateMonthDay();
  
  const short_hash = if (config.git_commit.len > 7) config.git_commit[0..7] 
  else config.git_commit;
  
  const time_ago = try formatTimeAgo(allocator, age_seconds);
  defer allocator.free(time_ago);
  const dirty_marker = if (config.git_dirty) "-dirty" else "";
  
  var buf: [4096]u8 = undefined;
  var writer = std.fs.File.stdout().writer(&buf);
  
  writer.interface.print("mango v{s}.{d}-g{s}{s} (released {d:0>4}-{d:0>2}-{d:0>2}, {s})\n", .{
    config.version, config.build_timestamp,
    short_hash, dirty_marker,
    year_day.year,
    month_day.month.numeric(),
    month_day.day_index + 1, time_ago,
  }) catch {};
  
  writer.interface.flush() catch {};
}

fn formatTimeAgo(allocator: std.mem.Allocator, seconds: i64) ![]const u8 {
  const abs_seconds = if (seconds < 0) -seconds else seconds;
  if (abs_seconds < 60) return allocator.dupe(u8, "just now");
  
  const TimeUnit = struct { divisor: i64, suffix: []const u8 };
  const unit: TimeUnit = if (abs_seconds < 3600) .{ .divisor = 60, .suffix = "m ago" }
  else if (abs_seconds < 86400) .{ .divisor = 3600, .suffix = "h ago" }
  else if (abs_seconds < 2592000) .{ .divisor = 86400, .suffix = "d ago" }
  else if (abs_seconds < 31536000) .{ .divisor = 2592000, .suffix = "mo ago" }
  else .{ .divisor = 31536000, .suffix = "y ago" };
  
  return std.fmt.allocPrint(allocator, "{d}{s}", .{ @divFloor(abs_seconds, unit.divisor), unit.suffix });
}
