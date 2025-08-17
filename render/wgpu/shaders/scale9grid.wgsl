/// Shader draws a cached bitmap with Scale9Grid scaling.
/// NOTE: common.wgsl is prepended before compilation.

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

struct Scale9Params {
    scale9_rect : vec4<f32>, // x_min, x_max, y_min, y_max in source texture space
    src_size    : vec2<f32>,
    dst_size    : vec2<f32>,
};

@group(1) @binding(0) var<uniform> transforms: common__Transforms;
@group(2) @binding(0) var<uniform> textureTransforms: common__TextureTransforms;
@group(2) @binding(1) var texture: texture_2d<f32>;
@group(2) @binding(2) var texture_sampler: sampler;
@group(3) @binding(0) var<uniform> scale9: Scale9Params;

@vertex
fn main_vertex(in: common__VertexInput) -> VertexOutput {
    let matrix_ = textureTransforms.texture_matrix;
    let uv = matrix_[0].xy * in.position.x + matrix_[1].xy * in.position.y + matrix_[2].xy;
    let pos = common__globals.view_matrix * transforms.world_matrix * vec4<f32>(in.position.x, in.position.y, 0.0, 1.0);

    return VertexOutput(pos, uv);
}

/// Maps a destination coordinate to the corresponding source texture coordinate
/// based on the 9-slice grid rules
fn map_scale9_coordinate(dst_coord: f32, dst_size: f32, src_size: f32, grid_min: f32, grid_max: f32) -> f32 {
    let grid_width = grid_max - grid_min;
    let corner_left = grid_min;
    let corner_right = src_size - grid_max;
    
    if (dst_coord < corner_left) {
        // Left corner: no scaling
        return dst_coord;
    } else if (dst_coord > dst_size - corner_right) {
        // Right corner: no scaling
        return src_size - (dst_size - dst_coord);
    } else {
        // Middle section: scale proportionally
        let middle_dst = dst_coord - corner_left;
        let middle_dst_size = dst_size - corner_left - corner_right;
        let middle_src_size = grid_width;
        return corner_left + (middle_dst / middle_dst_size) * middle_src_size;
    }
}

@fragment
fn main_fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    // Calculate the destination pixel coordinates (0 to dst_size)
    let dst_x = in.uv.x * scale9.dst_size.x;
    let dst_y = in.uv.y * scale9.dst_size.y;
    
    // Map destination coordinates to source texture coordinates using 9-slice logic
    let src_x = map_scale9_coordinate(dst_x, scale9.dst_size.x, scale9.src_size.x, scale9.scale9_rect.x, scale9.scale9_rect.y);
    let src_y = map_scale9_coordinate(dst_y, scale9.dst_size.y, scale9.src_size.y, scale9.scale9_rect.z, scale9.scale9_rect.w);
    
    // Convert to normalized texture coordinates (0.0 to 1.0)
    let texture_uv = vec2<f32>(src_x / scale9.src_size.x, src_y / scale9.src_size.y);
    
    // Debug: Check if UV coordinates are in valid range
    if (texture_uv.x < 0.0 || texture_uv.x > 1.0 || texture_uv.y < 0.0 || texture_uv.y > 1.0) {
        // Return red for invalid UV coordinates to help debug
        return vec4<f32>(1.0, 0.0, 0.0, 1.0);
    }
    
    // Debug: Show the calculated values as colors
    // Red channel shows normalized src_x, Green channel shows normalized src_y
    // This will help visualize what UV coordinates are being calculated
    let debug_color = vec4<f32>(texture_uv.x, texture_uv.y, 0.0, 1.0);
    
    // Sample the texture with the calculated UV coordinates
    var color: vec4<f32> = textureSample(texture, texture_sampler, texture_uv);

    if (color.a > 0.0) {
        color = vec4<f32>(color.rgb / color.a, color.a);
        color = color * transforms.mult_color + transforms.add_color;
        color = vec4<f32>(color.rgb * color.a, color.a);
    }

    // For now, return debug color to see what's happening
    return debug_color;
}