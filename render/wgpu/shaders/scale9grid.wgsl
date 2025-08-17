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

@fragment
fn main_fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    // The WGPU renderer already handles the 9-slice logic by generating the correct geometry
    // Each quad maps a specific source region to a specific destination region
    // So we just sample the texture normally - no UV transformation needed!
    var color: vec4<f32> = textureSample(texture, texture_sampler, in.uv);

    if (color.a > 0.0) {
        color = vec4<f32>(color.rgb / color.a, color.a);
        color = color * transforms.mult_color + transforms.add_color;
        color = vec4<f32>(color.rgb * color.a, color.a);
    }

    return color;
}