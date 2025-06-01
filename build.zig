const std = @import("std");
const builtin = @import("builtin");
const zmpl_build = @import("zmpl");

const use_llvm_default = switch(builtin.cpu.arch) {
    .x86, .x86_64 => builtin.os.tag != .linux,
    else => true,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const templates_paths = try zmpl_build.templatesPaths(
        b.allocator,
        &.{
            .{ .prefix = "views", .path = &.{ "src", "view" } },
        },
    );

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "web_example",
        .root_module = exe_mod,
    });

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize
    });
    const zmpl_dep = b.dependency("zmpl", .{
        .target = target,
        .optimize = optimize,
        .use_llvm = b.option(bool, "use_llvm", "Use LLVM") orelse use_llvm_default,
        .zmpl_templates_paths = templates_paths,
        .zmpl_auto_build = false
    });

    const zmpl_steps = zmpl_dep.builder.top_level_steps;
    const zmpl_compile_step = zmpl_steps.get("compile").?;
    const compile_step = b.step("compile", "Compile Zmpl templates");
    compile_step.dependOn(&zmpl_compile_step.step);

    exe.root_module.addImport("httpz", httpz.module("httpz"));
    exe.root_module.addImport("zmpl", zmpl_dep.module("zmpl"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
