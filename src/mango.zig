const std = @import("std");
const lmdbx = @import("lmdbx");
const config = @import("config");
const cli = @import("cli.zig");
const helpers = @import("helpers.zig");
const kv = @import("kv.zig");

const Command = enum { 
  get, set, del, list, 
  save, range, prefix,
  help, version 
};

fn parseCommand(arg: []const u8) ?Command {
  const map = .{
    .{ "get",       .get },
    .{ "set",       .set },
    .{ "del",       .del },
    .{ "list",      .list },
    .{ "save",      .save },
    .{ "range",     .range },
    .{ "prefix",    .prefix },
    .{ "help",      .help },
    .{ "--help",    .help },
    .{ "-h",        .help },
    .{ "--version", .version },
    .{ "-V",        .version },
  };
  inline for (map) |entry| {
    if (std.mem.eql(u8, arg, entry[0])) return entry[1];
  }
  return null;
}

const HelpEntry = struct { []const u8, []const u8 };

const options: []const HelpEntry = &.{
  .{ "-p, --path <PATH>", "kv path (default: ~/.mango)" },
  .{ "-s, --silent",      "suppress/reduce output" },
  .{ "-h, --help",        "print help (this)" },
  .{ "-V, --version",     "print version" },
};

const commands: []const HelpEntry = &.{
  .{ "get <key>",          "print a value from the store" },
  .{ "set <key> <value>",  "set a value in the store" },
  .{ "del <key>",          "remove a value from the store" },
  .{ "list",               "list all values in the store" },
  .{ "save <filename>",    "save store to csv file" },
  .{ "range <start> <end>","range between values in the store" },
  .{ "prefix <prefix>",    "search keys by prefix" },
};

fn printHelp() void {
  cli.printf("<#FF8F61>mango %s</> - simple key-value store backed by libMDBX\n", .{config.version});
  cli.printf("\n<bold>usage:</>\n", .{});
  cli.printf("  <#FF8F61>mango</> <#FB8065>[...options]</> <#F1B040><<command>></>\n", .{});

  cli.printf("\n<bold>options:</>\n", .{});
  for (options) |entry| cli.printf("  <pad=22><#83DD2D>%s</></pad><#FFDEB6>%s</>\n", .{ entry[0], entry[1] });

  cli.printf("\n<bold>commands:</>\n", .{});
  for (commands) |entry| cli.printf("  <pad=22><#83DD2D>%s</></pad><#FFDEB6>%s</>\n", .{ entry[0], entry[1] });

  cli.printf("\n", .{});
}

pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();  
  const allocator = gpa.allocator();

  const args = try std.process.argsAlloc(allocator);
  defer std.process.argsFree(allocator, args);

  var silent = false;
  var path: ?[]const u8 = null;
  var command: ?Command = null;
  
  var cmd_args: std.ArrayListUnmanaged([]const u8) = .empty;
  defer cmd_args.deinit(allocator);

  var i: usize = 1;
  while (i < args.len) : (i += 1) {
    const arg = args[i];
    if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--path")) {
      i += 1;
      if (i < args.len) path = args[i] 
      else {
        cli.printf("<bold_red>error:</> --path requires a value\n", .{});
        std.process.exit(1);
      }
    } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--silent")) {
      silent = true;
    } else if (command == null) {
      command = parseCommand(arg);
      if (command == null) {
        cli.printf("<bold_red>error:</> unknown command <yellow>'%s'</>\n", .{arg});
        printHelp();
        std.process.exit(1);
      }
    } else try cmd_args.append(allocator, arg);
  }

  const db_path = path orelse try helpers.getDefaultKvPath(allocator);
  defer if (path == null) allocator.free(db_path);

  const cmd = command orelse {
    printHelp();
    return;
  };

  switch (cmd) {
    .help => printHelp(),
    .version => try cli.printVersion(allocator),
    .get => {
      if (cmd_args.items.len < 1) {
        cli.printf("<bold_red>error:</> get requires a <yellow><<key>></> argument\n", .{});
        std.process.exit(1);
      }
      const result = kv.get(allocator, db_path, cmd_args.items[0]) catch {
        cli.printf("Unable to get <yellow>'%s'</>, does it exist?\n", .{cmd_args.items[0]});
        std.process.exit(1);
      };
      defer allocator.free(result);
      cli.printf("%s\n", .{result});
    },
    .set => {
      if (cmd_args.items.len < 2) {
        cli.printf("<bold_red>error:</> set requires <yellow><<key>> <<value>></> arguments\n", .{});
        std.process.exit(1);
      }
      kv.set(db_path, cmd_args.items[0], cmd_args.items[1]) catch {
        cli.printf("Unable to set <yellow>'%s'</>, is the store path correct?\n", .{cmd_args.items[0]});
        std.process.exit(1);
      };
      if (!silent) {
        cli.printf("<green>added key '%s' with value '%s'</>\n", .{ cmd_args.items[0], cmd_args.items[1] });
      }
    },
    .del => {
      if (cmd_args.items.len < 1) {
        cli.printf("<bold_red>error:</> del requires a <yellow><<key>></> argument\n", .{});
        std.process.exit(1);
      }
      kv.delete(db_path, cmd_args.items[0]) catch {
        cli.printf("Unable to remove <yellow>'%s'</>, does it exist?\n", .{cmd_args.items[0]});
        std.process.exit(1);
      };
      if (!silent) {
        cli.printf("<red>removed key '%s'</>\n", .{cmd_args.items[0]});
      }
    },
    .list => {
      kv.list(allocator, db_path, silent) catch {
        cli.printf("Unable to list all keys, is the store path correct?\n", .{});
        std.process.exit(1);
      };
    },
    .save => {
      if (cmd_args.items.len < 1) {
        cli.printf("<bold_red>error:</> save requires a <yellow><<filename>></> argument\n", .{});
        std.process.exit(1);
      }
      kv.save(allocator, db_path, cmd_args.items[0]) catch {
        cli.printf("Unable to save keys to file, is the store path correct?\n", .{});
        std.process.exit(1);
      };
      if (!silent) {
        cli.printf("<green>saved store '%s' to '%s'</>\n", .{ db_path, cmd_args.items[0] });
      }
    },
    .range => {
      if (cmd_args.items.len < 2) {
        cli.printf("<bold_red>error:</> range requires <yellow><<start>> <<end>></> arguments\n", .{});
        std.process.exit(1);
      }
      kv.range(allocator, db_path, cmd_args.items[0], cmd_args.items[1]) catch {
        cli.printf("Unable to range between keys, is the store path correct?\n", .{});
        std.process.exit(1);
      };
    },
    .prefix => {
      if (cmd_args.items.len < 1) {
        cli.printf("<bold_red>error:</> prefix requires a <yellow><<prefix>></> argument\n", .{});
        std.process.exit(1);
      }
      kv.prefix(allocator, db_path, cmd_args.items[0]) catch {
        cli.printf("Unable to search by prefix, is the store path correct?\n", .{});
        std.process.exit(1);
      };
    },
  }
}
