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
    const libb_mod = b.addModule("libb", .{
        .root_source_file = b.path("src/libb.zig"),
        .target = target,
        .optimize = optimize,
    });
    const bcompiler_mod = b.createModule(.{
        .root_source_file = b.path("src/b.zig"),
        .target = target,
        .optimize = optimize,
    });

    const libb_deps: []const Import = &.{
        .{ .name = "config", .module = mod: {
            const opts = b.addOptions();
            opts.addOption(SemanticVersion, "version", try SemanticVersion.parse(manifest.version));
            break :mod opts.createModule();
        } },
        .{ .name = "libb", .module = libb_mod },
    };
    const bcompiler_deps: []const Import = &.{
        .{ .name = "libb", .module = libb_mod },
        .{ .name = "b", .module = bcompiler_mod },
    };
    for (libb_deps) |dep| libb_mod.addImport(dep.name, dep.module);
    for (bcompiler_deps) |dep| bcompiler_mod.addImport(dep.name, dep.module);

    // Targets
    const libb = b.addLibrary(.{
        .name = "b",
        .linkage = .static,
        .root_module = libb_mod,
        .use_llvm = true,
    });
    const libb_check = b.addLibrary(.{ .name = "libb", .root_module = libb_mod });
    const libb_tests = b.addTest(.{
        .name = "libbtest",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/libb.zig"),
            .imports = &.{.{ .name = "libb", .module = libb_mod }},
            .target = target,
            .optimize = optimize,
        }),
    });

    const bcompiler = b.addExecutable(.{
        .name = "b",
        .linkage = .static,
        .root_module = bcompiler_mod,
        .use_llvm = true,
    });
    const bcompiler_check = b.addLibrary(.{ .name = "b", .root_module = bcompiler_mod });
    const bcompiler_tests = b.addTest(.{
        .name = "btest",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/b.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "b", .module = bcompiler_mod }},
        }),
    });

    // Install
    b.installArtifact(libb);
    b.installArtifact(bcompiler);
    b.installArtifact(libb_tests); // Useful for debugging
    b.installArtifact(bcompiler_tests); // "

    // Run
    const run_cmd = b.addRunArtifact(bcompiler);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test
    const run_lib_unit_tests = b.addRunArtifact(libb_tests);
    const run_b_unit_tests = b.addRunArtifact(bcompiler_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_b_unit_tests.step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(fs.path.basename(b.install_path))).step);
    if (builtin.os.tag != .windows)
        clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);

    // Check Step
    const check_step = b.step("check", "Check that the build artifacts are up-to-date");
    check_step.dependOn(&bcompiler_check.step);
    check_step.dependOn(&libb_check.step);
}
