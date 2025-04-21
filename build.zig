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
    const manifest = try zon.parse.fromSlice(
        struct { version: []const u8 },
        b.allocator,
        @embedFile("build.zig.zon"),
        null,
        .{ .ignore_unknown_fields = true },
    );

    // Modules and Deps
    const libb_mod = b.createModule(.{
        .root_source_file = b.path("src/lib🅱️.zig"),
        .target = target,
        .optimize = optimize,
    });
    const b_mod = b.createModule(.{
        .root_source_file = b.path("src/🅱️.zig"),
        .target = target,
        .optimize = optimize,
    });

    const libb_deps: []const Import = &.{
        .{ .name = "config", .module = mod: {
            const opts = b.addOptions();
            opts.addOption(SemanticVersion, "version", try SemanticVersion.parse(manifest.version));
            break :mod opts.createModule();
        } },
        .{ .name = "lib🅱️", .module = libb_mod },
    };
    for (libb_deps) |dep| libb_mod.addImport(dep.name, dep.module);

    const b_deps: []const Import = &.{
        .{ .name = "lib🅱️", .module = libb_mod },
        .{ .name = "🅱️", .module = b_mod },
    };
    for (b_deps) |dep| b_mod.addImport(dep.name, dep.module);

    // Targets
    const libb = b.addLibrary(.{
        .name = "🅱️",
        .linkage = .static,
        .root_module = libb_mod,
    });
    const libb_check = b.addLibrary(.{ .name = "🅱️", .root_module = libb_mod });
    const libb_tests = b.addTest(.{ .root_module = libb_mod });

    const bexe = b.addExecutable(.{
        .name = "🅱️",
        .linkage = .static,
        .root_module = b_mod,
    });
    const bexe_check = b.addLibrary(.{ .name = "🅱️", .root_module = b_mod });
    const bexe_tests = b.addTest(.{ .root_module = b_mod });

    // Install
    b.installArtifact(libb);
    b.installArtifact(bexe);
    b.installArtifact(libb_tests); // Useful for debugging
    b.installArtifact(bexe_tests); // "

    // Run
    const run_cmd = b.addRunArtifact(bexe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test
    const run_lib_unit_tests = b.addRunArtifact(libb_tests);
    const run_bexe_unit_tests = b.addRunArtifact(bexe_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_bexe_unit_tests.step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(fs.path.basename(b.install_path))).step);
    if (builtin.os.tag != .windows)
        clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);

    // Check Step
    const check_step = b.step("check", "Check that the build artifacts are up-to-date");
    check_step.dependOn(&bexe_check.step);
    check_step.dependOn(&libb_check.step);
}
