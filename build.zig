const std = @import("std");

pub fn build(b: *std.Build) void {
    const clap = b.dependency("clap", .{});

    const exe = b.addExecutable(.{
        .name = "png",
        .root_source_file = b.path("src/png.zig"),
        .target = b.graph.host,
    });

    exe.root_module.addImport("clap", clap.module("clap"));
    b.installArtifact(exe);

    // Neural network standalone executable
    const nn_exe = b.addExecutable(.{
        .name = "nn",
        .root_source_file = b.path("src/nn.zig"),
        .target = b.graph.host,
    });
    nn_exe.root_module.addImport("clap", clap.module("clap"));

    b.installArtifact(nn_exe);
}
