const std = @import("std");
const SemanticVersion = std.SemanticVersion;
const zon = std.zon;
const fs = std.fs;
const Build = std.Build;
const Step = Build.Step;
const Module = Build.Module;
const Import = Module.Import;
const builtin = @import("builtin");

pub fn build(bld: *std.Build) !void {
    const target = bld.standardTargetOptions(.{ .default_target = .{ .abi = .musl } });
    const optimize = bld.standardOptimizeOption(.{});
    const manifest = try zon.parse.fromSlice(
        struct { version: []const u8 },
        bld.allocator,
        @embedFile("build.zig.zon"),
        null,
        .{ .ignore_unknown_fields = true },
    );

    // Modules and Deps
    const libb_mod = bld.createModule(.{
        .root_source_file = bld.path("src/libb.zig"),
        .target = target,
        .optimize = optimize,
    });
    const bcompiler_mod = bld.createModule(.{
        .root_source_file = bld.path("src/b.zig"),
        .target = target,
        .optimize = optimize,
    });

    const libb_deps: []const Import = &.{
        .{ .name = "config", .module = mod: {
            const opts = bld.addOptions();
            opts.addOption(SemanticVersion, "version", try SemanticVersion.parse(manifest.version));
            break :mod opts.createModule();
        } },
        .{ .name = "libb", .module = libb_mod },
    };
    for (libb_deps) |dep| libb_mod.addImport(dep.name, dep.module);

    const b_deps: []const Import = &.{
        .{ .name = "libb", .module = libb_mod },
        .{ .name = "b", .module = bcompiler_mod },
    };
    for (b_deps) |dep| bcompiler_mod.addImport(dep.name, dep.module);

    // Targets
    const libb = bld.addLibrary(.{
        .name = "b",
        .linkage = .static,
        .root_module = libb_mod,
    });
    const libb_check = bld.addLibrary(.{ .name = "libb", .root_module = libb_mod });
    const libb_tests = bld.addTest(.{ .root_module = libb_mod });

    const b = bld.addExecutable(.{
        .name = "b",
        .linkage = .static,
        .root_module = bcompiler_mod,
    });
    const b_check = bld.addLibrary(.{ .name = "b", .root_module = bcompiler_mod });
    const b_tests = bld.addTest(.{ .root_module = bcompiler_mod });

    // Install
    bld.installArtifact(libb);
    bld.installArtifact(b);
    bld.installArtifact(libb_tests); // Useful for debugging
    bld.installArtifact(b_tests); // "

    // Run
    const run_cmd = bld.addRunArtifact(b);
    run_cmd.step.dependOn(bld.getInstallStep());
    if (bld.args) |args| run_cmd.addArgs(args);
    const run_step = bld.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test
    const run_lib_unit_tests = bld.addRunArtifact(libb_tests);
    const run_b_unit_tests = bld.addRunArtifact(b_tests);
    const test_step = bld.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_b_unit_tests.step);

    // Clean
    const clean_step = bld.step("clean", "Remove build artifacts");
    clean_step.dependOn(&bld.addRemoveDirTree(bld.path(fs.path.basename(bld.install_path))).step);
    if (builtin.os.tag != .windows)
        clean_step.dependOn(&bld.addRemoveDirTree(bld.path(".zig-cache")).step);

    // Check Step
    const check_step = bld.step("check", "Check that the build artifacts are up-to-date");
    check_step.dependOn(&b_check.step);
    check_step.dependOn(&libb_check.step);
}
