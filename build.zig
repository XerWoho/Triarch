// const std = @import("std");

// pub fn build(b: *std.Build) void {
//     const exe = b.addExecutable(.{
//         .name = "main",
//         .root_source_file = b.path("src/main.zig"),
//         .target = b.graph.host,
//     });

//     const clap = b.dependency("clap", .{});
//     exe.root_module.addImport("clap", clap.module("clap"));

//     b.installArtifact(exe);
// }




const std = @import("std");

pub fn build(b: *std.Build) void {
    // Main executable (guesser)
    const exe = b.addExecutable(.{
        .name = "png",
        .root_source_file = b.path("src/png.zig"),
        .target = b.graph.host,

    });

    const clap = b.dependency("clap", .{});
    exe.root_module.addImport("clap", clap.module("clap"));

    b.installArtifact(exe);

    // Neural network standalone executable
    const nn_exe = b.addExecutable(.{
        .name = "nn",
        .root_source_file = b.path("src/nn.zig"),
        .target = b.graph.host,
    });

    b.installArtifact(nn_exe);
}
