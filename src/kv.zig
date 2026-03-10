const std = @import("std");
const lmdbx = @import("lmdbx");
const helpers = @import("helpers.zig");

fn openEnv(path: []const u8) !lmdbx.Environment {
  const c_path = @as([*:0]const u8, @ptrCast(path.ptr));
  return lmdbx.Environment.init(c_path, .{});
}

pub fn get(allocator: std.mem.Allocator, path: []const u8, key: []const u8) ![]const u8 {
  const env = try openEnv(path);
  defer env.deinit() catch {};

  const txn = try env.transaction(.{ .mode = .ReadOnly });
  defer txn.abort() catch {};

  const val = (try txn.get(key)) orelse return error.KeyNotFound;
  return try allocator.dupe(u8, val);
}

pub fn set(path: []const u8, key: []const u8, value: []const u8) !void {
  const env = try openEnv(path);
  defer env.deinit() catch {};

  const txn = try env.transaction(.{ .mode = .ReadWrite });
  errdefer txn.abort() catch {};

  try txn.set(key, value, .Upsert);
  try txn.commit();
}

pub fn delete(path: []const u8, key: []const u8) !void {
  const env = try openEnv(path);
  defer env.deinit() catch {};

  const txn = try env.transaction(.{ .mode = .ReadWrite });
  errdefer txn.abort() catch {};

  try txn.delete(key);
  try txn.commit();
}

pub fn list(allocator: std.mem.Allocator, path: []const u8, silent: bool) !void {
  const env = try openEnv(path);
  defer env.deinit() catch {};

  const txn = try env.transaction(.{ .mode = .ReadOnly });
  defer txn.abort() catch {};

  var cur = try txn.cursor();
  defer cur.deinit();

  var keys: std.ArrayListUnmanaged([]const u8) = .empty;
  defer keys.deinit(allocator);
  var values: std.ArrayListUnmanaged([]const u8) = .empty;
  defer values.deinit(allocator);

  var key = try cur.goToFirst();
  while (key != null) {
    const entry = try cur.getCurrentEntry();
    try keys.append(allocator, entry.key);
    try values.append(allocator, entry.value);
    key = cur.goToNext() catch null;
  }

  if (silent) try helpers.printJson(allocator, keys.items, values.items)
  else try helpers.printDotTable(allocator, keys.items, values.items);
}

pub fn range(allocator: std.mem.Allocator, path: []const u8, start: []const u8, end: []const u8) !void {
  const env = try openEnv(path);
  defer env.deinit() catch {};

  const txn = try env.transaction(.{ .mode = .ReadOnly });
  defer txn.abort() catch {};

  var cur = try txn.cursor();
  defer cur.deinit();

  var keys: std.ArrayListUnmanaged([]const u8) = .empty;
  defer keys.deinit(allocator);
  var values: std.ArrayListUnmanaged([]const u8) = .empty;
  defer values.deinit(allocator);

  _ = cur.seek(start) catch null;

  while (true) {
    const entry = cur.getCurrentEntry() catch break;
    if (std.mem.order(u8, entry.key, end) != .lt) break;
    try keys.append(allocator, entry.key);
    try values.append(allocator, entry.value);
    _ = cur.goToNext() catch break orelse break;
  }

  try helpers.printJson(allocator, keys.items, values.items);
}

pub fn prefix(allocator: std.mem.Allocator, path: []const u8, pfx: []const u8) !void {
  const env = try openEnv(path);
  defer env.deinit() catch {};

  const txn = try env.transaction(.{ .mode = .ReadOnly });
  defer txn.abort() catch {};

  var cur = try txn.cursor();
  defer cur.deinit();

  var keys: std.ArrayListUnmanaged([]const u8) = .empty;
  defer keys.deinit(allocator);
  var values: std.ArrayListUnmanaged([]const u8) = .empty;
  defer values.deinit(allocator);

  _ = cur.seek(pfx) catch null;

  while (true) {
    const entry = cur.getCurrentEntry() catch break;
    if (!std.mem.startsWith(u8, entry.key, pfx)) break;
    try keys.append(allocator, entry.key);
    try values.append(allocator, entry.value);
    _ = cur.goToNext() catch break orelse break;
  }

  try helpers.printJson(allocator, keys.items, values.items);
}

pub fn save(allocator: std.mem.Allocator, path: []const u8, filename: []const u8) !void {
  const env = try openEnv(path);
  defer env.deinit() catch {};

  const txn = try env.transaction(.{ .mode = .ReadOnly });
  defer txn.abort() catch {};

  var cur = try txn.cursor();
  defer cur.deinit();

  var keys: std.ArrayListUnmanaged([]const u8) = .empty;
  defer keys.deinit(allocator);
  var values: std.ArrayListUnmanaged([]const u8) = .empty;
  defer values.deinit(allocator);

  var key = try cur.goToFirst();
  while (key != null) {
    const entry = try cur.getCurrentEntry();
    try keys.append(allocator, entry.key);
    try values.append(allocator, entry.value);
    key = cur.goToNext() catch null;
  }

  const file = try std.fs.cwd().createFile(filename, .{});
  defer file.close();

  for (keys.items, values.items) |k, v| {
    try helpers.writeCsvField(file, k);
    try file.writeAll(",");
    try helpers.writeCsvField(file, v);
    try file.writeAll("\n");
  }
}
