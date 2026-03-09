const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ipMod = b.addModule("ip", .{ .root_source_file = b.path("src/main.zig"), .optimize = optimize, .target = target });

    const unit_tests = b.addTest(.{
        .name = "test",
        .root_module = b.createModule(.{ .root_source_file = b.path("test/main.zig"), .target = target, .optimize = optimize }),
    });
    unit_tests.root_module.addImport("ip", ipMod);

    {
        const run_tests_step = b.addRunArtifact(unit_tests);

        const test_step = b.step("test", "Run library tests");
        test_step.dependOn(&run_tests_step.step);
    }
}