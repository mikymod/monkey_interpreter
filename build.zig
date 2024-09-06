const std = @import("std");

const test_targets = [_]std.Target.Query{
    .{}, // native
    // .{
    //     .cpu_arch = .x86_64,
    //     .os_tag = .linux,
    // },
    // .{
    //     .cpu_arch = .aarch64,
    //     .os_tag = .macos,
    // },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lexer = b.addSharedLibrary(.{
        .name = "lexer",
        .root_source_file = b.path("lexer/lexer.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 1, .minor = 2, .patch = 3 },
    });

    b.installArtifact(lexer);

    const parser = b.addSharedLibrary(.{
        .name = "parser",
        .root_source_file = b.path("ast/parser.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 1, .minor = 2, .patch = 3 },
    });

    b.installArtifact(parser);

    const exe = b.addExecutable(.{
        .name = "monkey_interpreter",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibrary(lexer);
    exe.linkLibrary(parser);

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    const test_step = b.step("test", "Run the tests");
    for (test_targets) |test_target| {
        const unit_test = b.addTest(
            .{
                .root_source_file = b.path("lexer/lexer_test.zig"),
                .target = b.resolveTargetQuery(test_target),
            },
        );

        const run_unit_tests = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_unit_tests.step);
    }
}
