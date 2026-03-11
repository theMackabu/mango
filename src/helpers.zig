const std = @import("std");

pub fn getDefaultKvPath(allocator: std.mem.Allocator) ![]const u8 {
  const home = std.process.getEnvVarOwned(allocator, "HOME") catch {
    std.debug.print("Home directory could not be found.\n", .{});
    std.process.exit(1);
  }; 
  
  defer allocator.free(home);
  const path = try std.fmt.allocPrint(allocator, "{s}/.mango", .{home});

  std.fs.makeDirAbsolute(path) catch |err| switch (err) {
    error.PathAlreadyExists => {},
    else => return err,
  };

  return path;
}

pub fn printJson(allocator: std.mem.Allocator, keys: []const []const u8, values: []const []const u8) !void {
  const buf = try allocator.alloc(u8, 4096);
  defer allocator.free(buf);
  var out = std.fs.File.stdout().writer(buf);
  defer out.interface.flush() catch {};

  var jw: std.json.Stringify = .{ .writer = &out.interface };
  try jw.beginObject();
  for (keys, values) |k, v| {
    try jw.objectField(k);
    try jw.write(v);
  }
  try jw.endObject();
  try out.interface.writeAll("\n");
}

pub fn printDotTable(allocator: std.mem.Allocator, keys: []const []const u8, values: []const []const u8) !void {
  const buf = try allocator.alloc(u8, 4096);
  defer allocator.free(buf);
  
  var out = std.fs.File.stdout().writer(buf);
  const w = &out.interface;
  defer w.flush() catch {};

  var max_key: usize = 0;
  for (keys) |k| {
    if (k.len > max_key) max_key = k.len;
  }

  for (keys, values) |k, v| {
    try w.print("  {s} ", .{k});
    for (0..max_key - k.len + 1) |_| try w.writeAll("·");

    var line_count: usize = 1;
    for (v) |c| {
      if (c == '\n') line_count += 1;
    }

    const trimmed = std.mem.trimLeft(u8, v, " \t\n\r");
    const is_json = trimmed.len > 0 and (trimmed[0] == '{' or trimmed[0] == '[');

    if (is_json) try w.print(" JSON ({d} lines)\n", .{line_count})
    else if (line_count > 1) {
      const first_line = if (std.mem.indexOfScalar(u8, v, '\n')) |idx| v[0..idx] else v;
      try w.print(" {s}\xe2\x80\xa6 ({d} lines)\n", .{ first_line, line_count });
    } else try w.print(" {s}\n", .{v});
  }
}

pub fn writeCsvField(file: std.fs.File, field: []const u8) !void {
  var needs_quote = false;
  for (field) |c| { if (c == ',' or c == '"' or c == '\n') { 
    needs_quote = true;
    break; 
  }}
  if (needs_quote) {
    try file.writeAll("\"");
    for (field) |c| {
      if (c == '"') try file.writeAll("\"\"")
      else try file.writeAll(&.{c});
    }
    try file.writeAll("\"");
  } else try file.writeAll(field);
}
