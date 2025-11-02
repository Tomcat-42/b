const std = @import("std");
const SemanticVersion = std.SemanticVersion;
const zon = std.zon;
const fs = std.fs;
const Build = std.Build;
const Step = Build.Step;
const Module = Build.Module;
const Import = Module.Import;
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .musl } });
    const optimize = b.standardOptimizeOption(.{});
    const manifest = try zon.parse.fromSliceAlloc(
        struct { version: []const u8 },
        b.allocator,
        @embedFile("build.zig.zon"),
        null,
        .{ .ignore_unknown_fields = true },
    );

    // Modules and Deps
    const lox_mod = b.addModule("lox", .{
        .root_source_file = b.path("src/lox.zig"),
        .target = target,
        .optimize = optimize,
    });
    const loxi_mod = b.createModule(.{
        .root_source_file = b.path("src/loxi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lox_deps: []const Import = &.{
        .{ .name = "manifest", .module = mod: {
            const opts = b.addOptions();
            opts.addOption(SemanticVersion, "version", try SemanticVersion.parse(manifest.version));
            break :mod opts.createModule();
        } },
        .{ .name = "lox", .module = lox_mod },
        .{ .name = "util", .module = b.dependency("util", .{ .optimize = optimize, .target = target }).module("util") },
    };
    const loxi_deps: []const Import = &.{
        .{ .name = "lox", .module = lox_mod },
        .{ .name = "loxi", .module = loxi_mod },
        .{ .name = "util", .module = b.dependency("util", .{ .optimize = optimize, .target = target }).module("util") },
    };
    for (lox_deps) |dep| lox_mod.addImport(dep.name, dep.module);
    for (loxi_deps) |dep| loxi_mod.addImport(dep.name, dep.module);

    // Targets
    const lox = b.addLibrary(.{
        .name = "lox",
        .linkage = .static,
        .root_module = lox_mod,
        .use_llvm = true,
    });
    const lox_check = b.addLibrary(.{ .name = "loxcheck", .root_module = lox_mod });
    const lox_tests = b.addTest(.{
        .name = "loxtest",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/lox.zig"),
            .imports = &.{.{ .name = "lox", .module = lox_mod }},
            .target = target,
            .optimize = optimize,
        }),
    });

    const loxi = b.addExecutable(.{
        .name = "loxi",
        .linkage = .static,
        .root_module = loxi_mod,
        .use_llvm = true,
    });
    const loxi_check = b.addLibrary(.{ .name = "loxicheck", .root_module = loxi_mod });
    const loxi_tests = b.addTest(.{
        .name = "loxitest",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/loxi.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "lox", .module = loxi_mod }},
        }),
    });

    // Install
    b.installArtifact(lox);
    b.installArtifact(loxi);
    b.installArtifact(lox_tests); // Useful for debugging
    b.installArtifact(loxi_tests); // "

    // Run
    const run_cmd = b.addRunArtifact(loxi);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test
    const run_lox_unit_tests = b.addRunArtifact(lox_tests);
    const run_loxi_unit_tests = b.addRunArtifact(loxi_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lox_unit_tests.step);
    test_step.dependOn(&run_loxi_unit_tests.step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(fs.path.basename(b.install_path))).step);
    if (builtin.os.tag != .windows)
        clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);

    // Check Step
    const check_step = b.step("check", "Check that the build artifacts are up-to-date");
    check_step.dependOn(&loxi_check.step);
    check_step.dependOn(&lox_check.step);
}
