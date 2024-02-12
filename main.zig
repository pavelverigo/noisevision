const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

const Color = packed struct(u32) {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    const BLACK: Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
    const WHITE: Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 };

    const RED: Color = .{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const GREEN: Color = .{ .r = 0, .g = 255, .b = 0, .a = 255 };
    const BLUE: Color = .{ .r = 0, .g = 0, .b = 255, .a = 255 };
};

var width: i32 = 400;
var height: i32 = 400;

const max_width = 800;
const max_height = 800;

var debug_image: [max_width * max_height]Color = undefined;
var noise_image: [max_width * max_height]Color = undefined;

fn pixel(x: i32, y: i32, c: Color) void {
    if (0 <= x and x < width and 0 <= y and y < height) {
        const pos: usize = @intCast(x + width * y);
        debug_image[pos] = c;
    }
}

fn line(x0: i32, y0: i32, x1: i32, y1: i32, c: Color) void {
    const dx = @as(i32, @intCast(@abs(x1 - x0)));
    const sx: i32 = if (x1 > x0) 1 else -1;
    const dy = -@as(i32, @intCast(@abs(y1 - y0)));
    const sy: i32 = if (y1 > y0) 1 else -1;

    var x: i32 = x0;
    var y: i32 = y0;
    var err = dx + dy;
    while (true) {
        pixel(x, y, c);
        if (x == x1 and y == y1) break;
        const err_2 = 2 * err;
        if (err_2 >= dy) {
            err += dy;
            x += sx;
        }
        if (err_2 <= dx) {
            err += dx;
            y += sy;
        }
    }
}

fn xor_pixel(x: i32, y: i32) void {
    if (0 <= x and x < width and 0 <= y and y < height) {
        const pos: usize = @intCast(x + width * y);
        const c = blk: {
            const cur = noise_image[pos];
            const eql = std.meta.eql;
            if (eql(cur, Color.BLACK)) break :blk Color.WHITE;
            if (eql(cur, Color.WHITE)) break :blk Color.BLACK;
            break :blk cur;
        };
        noise_image[pos] = c;
    }
}

fn xor_line(x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dx = @as(i32, @intCast(@abs(x1 - x0)));
    const sx: i32 = if (x1 > x0) 1 else -1;
    const dy = -@as(i32, @intCast(@abs(y1 - y0)));
    const sy: i32 = if (y1 > y0) 1 else -1;

    var x: i32 = x0;
    var y: i32 = y0;
    var err = dx + dy;
    while (true) {
        xor_pixel(x, y);
        if (x == x1 and y == y1) break;
        const err_2 = 2 * err;
        if (err_2 >= dy) {
            err += dy;
            x += sx;
        }
        if (err_2 <= dx) {
            err += dx;
            y += sy;
        }
    }
}

fn clear(c: Color) void {
    @memset(debug_image[0..], c);
}

var global_vertex_storage: [1000]Vertex = undefined;
var global_edge_storage: [1000]Edge = undefined;

const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,
};

const Edge = struct {
    i: u16,
    j: u16,
};

const Geom = struct {
    vertices: []Vertex,
    edges: []Edge,
};

const GEOM_COUNT = 4;
var geoms: [GEOM_COUNT]Geom = undefined;

export fn start() void {
    { // geom
        const geom_paths = [GEOM_COUNT][]const u8{
            "3d/triangle.obj",
            "3d/cube.obj",
            "3d/tesseract.obj",
            "3d/torus.obj",
        };

        var vex_count: usize = 0;
        var edge_count: usize = 0;

        inline for (geom_paths, 0..) |path, i| {
            const file_data = @embedFile(path);
            var line_it = std.mem.tokenizeAny(u8, file_data, "\n");
            const vex_offset = vex_count;
            const edge_offset = edge_count;

            while (line_it.next()) |ln| {
                var it = std.mem.tokenizeAny(u8, ln, " ");

                const begin = it.next().?;
                if (mem.eql(u8, begin, "#")) {
                    continue;
                } else if (mem.eql(u8, begin, "o")) {
                    continue;
                } else if (mem.eql(u8, begin, "v")) {
                    const x = std.fmt.parseFloat(f32, it.next().?) catch unreachable;
                    const y = std.fmt.parseFloat(f32, it.next().?) catch unreachable;
                    const z = std.fmt.parseFloat(f32, it.next().?) catch unreachable;
                    global_vertex_storage[vex_count] = .{ .x = x, .y = y, .z = z };
                    vex_count += 1;
                } else if (mem.eql(u8, begin, "l")) {
                    const ii = std.fmt.parseInt(u16, it.next().?, 10) catch unreachable;
                    const jj = std.fmt.parseInt(u16, it.next().?, 10) catch unreachable;
                    global_edge_storage[edge_count] = .{ .i = ii - 1, .j = jj - 1 };
                    edge_count += 1;
                } else {
                    @panic("unknown tag");
                }
            }

            geoms[i] = .{
                .vertices = global_vertex_storage[vex_offset..vex_count],
                .edges = global_edge_storage[edge_offset..edge_count],
            };
        }
    }

    { // background
        var rand = std.rand.Xoroshiro128.init(0);
        const size = max_width * max_height;
        comptime assert(size % 64 == 0);
        for (0..(size / 64)) |i| {
            const bits = rand.next();
            inline for (0..64) |j| {
                const v = (bits & (1 << j)) != 0;
                const c = if (v) Color.WHITE else Color.BLACK;
                noise_image[i * 64 + j] = c;
            }
        }
    }
}

var t: f32 = 0;

fn pixelPosApprox(x: f32) i32 {
    return @intFromFloat(math.round(x));
}

fn rotate(v: Vertex, a: f32, b: f32, c: f32) Vertex {
    const R11 = @cos(b) * @cos(c);
    const R12 = @cos(c) * @sin(a) * @sin(b) - @cos(a) * @sin(c);
    const R13 = @sin(a) * @sin(c) + @cos(a) * @cos(c) * @sin(b);

    const R21 = @cos(b) * @sin(c);
    const R22 = @cos(a) * @cos(c) + @sin(a) * @sin(b) * @sin(c);
    const R23 = @cos(a) * @sin(b) * @sin(c) - @cos(c) * @sin(a);

    const R31 = -@sin(b);
    const R32 = @cos(b) * @sin(a);
    const R33 = @cos(a) * @cos(b);

    return .{
        .x = R11 * v.x + R12 * v.y + R13 * v.z,
        .y = R21 * v.x + R22 * v.y + R23 * v.z,
        .z = R31 * v.x + R32 * v.y + R33 * v.z,
    };
}

fn mapToScreen(x: f32) f32 {
    const half = @as(f32, @floatFromInt(width)) / 2.0;
    return x * half + half;
}

export fn frame(dt: f32, geom_idx: u32, debug: bool, speed: f32, size: i32, pause: bool) [*]Color {
    width = size;
    height = size;

    if (!pause) t += dt / 1000 * speed;

    if (debug) clear(Color.BLACK);

    const geom = geoms[geom_idx];
    for (geom.edges) |edge| {
        const a = t / 10;
        const b = t / 40;
        const c = t / 60;
        const v0 = rotate(geom.vertices[edge.i], a, b, c);
        const v1 = rotate(geom.vertices[edge.j], a, b, c);
        const x0 = pixelPosApprox(mapToScreen(v0.x));
        const y0 = pixelPosApprox(mapToScreen(v0.y));
        const x1 = pixelPosApprox(mapToScreen(v1.x));
        const y1 = pixelPosApprox(mapToScreen(v1.y));
        if (debug) {
            line(x0, y0, x1, y1, Color.WHITE);
        } else {
            if (!pause) xor_line(x0, y0, x1, y1);
        }
    }

    return if (debug) &debug_image else &noise_image;
}
