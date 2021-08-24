const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const c_obj = b.addObject("stb_image_write", null);
    c_obj.setBuildMode(mode);
    c_obj.addCSourceFile("stb_image_write/stb_image_write.c", &[_][]const u8{"-fno-strict-aliasing"});
    c_obj.linkSystemLibrary("c");

    const exe = b.addExecutable("generative", "main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addObject(c_obj);
    exe.addIncludeDir("stb_image_write");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
