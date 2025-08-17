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
fn main_vertex(in: common__VertexInput)  -> VertexOutput {
    let matrix_ = textureTransforms.texture_matrix
    let uv = (mat3x3<f32>(matrix_[0].xyz, matrix_[1].xyz, matrix_[2].xyz)) * vec3<f32>(in.position, 1.0).xy
    let pos = common__globals.view_matrix * transforms.world_matrix * vec4<f32>(in.position.x, in.position.y, 0.0, 1.0);

    return VertexOutput(pos, uv)
}

fn map_scale9_1d(src: f32, src_size: f32, dst_size: f32, rect_min: f32, rect_max: f32) -> f32{
    let left_size = rect_min;
    let right_size = src_size - rect_max;
    let middle_size = rect_max - rect_min;

    if(src < left_size) {
        return left; // left
    }
    else if(src > src_size - right_size) {
        return dst_size - (src_size - src)//right
    }
    else {
        return left + (src - left) * ((dst_size - left - right) / middle); //middle
    }
}

fn map_uv(uv: vec2<f32>) -> vec2<f32> {
    let src_pos = uv * scale9.src_size;
    let dst_x = map_scale9_1d(src_pos.x, u_scale9.src_size.x, u_scale9.dst_size.x, u_scale9.scale9_rect.x, u_scale9.scale9_rect.y);
    let dst_y = map_scale9_1d(src_pos.y, u_scale9.src_size.y, u_scale9.dst_size.y, u_scale9.scale9_rect.z, u_scale9.scale9_rect.w);
    return vec2<f32>(dst_x / scale9.src_size.x, dst_y / scale9.src_size.y);
}

@fragment
fn main_fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    var color: vec4<f32> = textureSample(bitmap_texture, bitmap_sampler, map_uv(in.uv));

    if (color.a > 0.0) {
        color = vec4<f32>(color.rgb / color.a, color.a);
        color = color * transforms.mult_color + transforms.add_color;
        if (!late_saturate) {
            color = saturate(color);
        }
        color = vec4<f32>(color.rgb * color.a, color.a);
        if (late_saturate) {
            color = saturate(color);
        }
    }

    return color;
}