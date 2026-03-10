const std = @import("std");
const utils = @import("build.utils.zig");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  const lmdbx_dep = b.dependency("lmdbx", .{
    .target = target,
    .optimize = optimize,
  });

  const crprintf_dep = b.dependency("crprintf", .{});

  const mango = b.createModule(.{
    .root_source_file = b.path("src/mango.zig"),
    .target = target,
    .optimize = optimize,
  });

  mango.addImport("lmdbx", lmdbx_dep.module("lmdbx"));
  mango.addIncludePath(crprintf_dep.path("src"));
  mango.addCSourceFile(.{ .file = crprintf_dep.path("src/crprintf.c") });
  mango.linkSystemLibrary("c", .{});

  const version = @import("build.zig.zon").version;
  const timestamp = std.time.timestamp();
  const git_commit = utils.getGitCommit(b) orelse "unknown";
  const git_branch = utils.getGitBranch(b) orelse "unknown";
  const git_dirty = utils.isGitDirty(b);

  const options = b.addOptions();
  options.addOption([]const u8, "version", version);
  options.addOption(i64, "build_timestamp", timestamp);
  options.addOption([]const u8, "git_commit", git_commit);
  options.addOption([]const u8, "git_branch", git_branch);
  options.addOption(bool, "git_dirty", git_dirty);

  mango.addImport("config", options.createModule());

  const bin = b.addExecutable(.{
    .name = "mango",
    .root_module = mango,
  });

  b.installArtifact(bin);

  const run_cmd = b.addRunArtifact(bin);
  run_cmd.step.dependOn(b.getInstallStep());
  if (b.args) |args| run_cmd.addArgs(args);

  const run_step = b.step("run", "Run mango");
  run_step.dependOn(&run_cmd.step);

  const install_local = b.step("install-local", "Install to ~/.local/bin");
  const install_cmd = b.addSystemCommand(&.{"cp", "-f"});
  install_cmd.addFileArg(bin.getEmittedBin());

  const home = b.graph.env_map.get("HOME") orelse return;
  const dest_path = b.fmt("{s}/.local/bin/mango", .{home});

  install_cmd.addArg(dest_path);
  install_local.dependOn(&install_cmd.step);
}
