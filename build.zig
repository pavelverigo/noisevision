const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            // https://webassembly.org/features/ Safari does not support tail calls => .cpu_model = .bleeding_edge non viable currently
            // Safari did have tail calls, but was reverted in the first quarter of 2023. Tracking issue https://bugs.webkit.org/show_bug.cgi?id=215275
            .cpu_features_add = std.Target.wasm.featureSet(&.{
                .bulk_memory,
                .multivalue,
                .mutable_globals,
                .nontrapping_fptoint,
                .sign_ext,
                .simd128,
            }),
            .os_tag = .freestanding,
        },
    });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const exe = b.addExecutable(.{
        .name = "noisevision",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // STRANGE/BUG zig compiler ignore changes in export_symbol_names and do not recompile, if src code did not change
    exe.root_module.export_symbol_names = &.{ "add", "frame", "start" };
    exe.entry = .disabled;

    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(exe.getEmittedBin(), exe.out_filename);
    _ = wf.addCopyFile(.{ .path = "index.html" }, "index.html");

    const www_dir = b.addInstallDirectory(.{ .source_dir = wf.getDirectory(), .install_dir = .prefix, .install_subdir = "www" });
    b.getInstallStep().dependOn(&www_dir.step);
}
