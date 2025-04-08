const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ipMod = b.addModule("ip", .{ .root_source_file = b.path("src/main.zig") });

    {
        const main_tests = b.addTest(.{ .root_source_file = b.path("test/main.zig"), .optimize = optimize, .target = target });
        main_tests.root_module.addImport("ip", ipMod);

        const run_tests_step = b.addRunArtifact(main_tests);

        const test_step = b.step("test", "Run library tests");
        test_step.dependOn(&run_tests_step.step);
    }
}