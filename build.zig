const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lexer_mod = b.addModule("lexer", .{
        .root_source_file = b.path("lexer/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    const parser_mod = b.addModule("parser", .{
        .root_source_file = b.path("ast/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    parser_mod.addImport("lexer", lexer_mod);

    // Builds tests
    const unit_tests = [_][]const u8{
        "lexer/lexer_test.zig",
        "ast/parser_test.zig",
    };

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

    const test_step = b.step("test", "Run the tests");
    for (unit_tests) |unit_test| {
        for (test_targets) |test_target| {
            const t = b.addTest(
                .{
                    .root_source_file = b.path(unit_test),
                    .target = b.resolveTargetQuery(test_target),
                },
            );

            t.root_module.addImport("lexer", lexer_mod);
            t.root_module.addImport("parser", parser_mod);

            // Run test
            const run_unit_tests = b.addRunArtifact(t);
            test_step.dependOn(&run_unit_tests.step);
        }
    }

    // Builds executable
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

    // Run after build
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}

pub fn build_tests(b: *std.Build) void {
    const unit_tests = [_][]const u8{
        "lexer/lexer_test.zig",
        "ast/parser_test.zig",
    };

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

    const test_step = b.step("test", "Run the tests");
    for (unit_tests) |unit_test| {
        for (test_targets) |test_target| {
            const t = b.addTest(
                .{
                    .root_source_file = b.path(unit_test),
                    .target = b.resolveTargetQuery(test_target),
                },
            );

            // Run test
            const run_unit_tests = b.addRunArtifact(t);
            test_step.dependOn(&run_unit_tests.step);
        }
    }
}
