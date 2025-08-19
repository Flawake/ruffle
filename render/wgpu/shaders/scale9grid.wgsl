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
    let matrix_ = textureTransforms.texture_matrix;
    let uv = (mat3x3<f32>(matrix_[0].xyz, matrix_[1].xyz, matrix_[2].xyz) * vec3<f32>(in.position, 1.0)).xy;
    let pos = common__globals.view_matrix * transforms.world_matrix * vec4<f32>(in.position.x, in.position.y, 0.0, 1.0);

    return VertexOutput(pos, uv);
}

fn map_scale9_1d(src: f32, src_size: f32, dst_size: f32, rect_min: f32, rect_max: f32) -> f32{
    let left_size = rect_min;
    let right_size = src_size - rect_max;
    let middle_size = rect_max - rect_min;

    if(src < left_size) {
        return left_size; // left
    }
    else if(src > src_size - right_size) {
        return dst_size - (src_size - src);//right
    }
    else {
        return left_size + (src - left_size) * ((dst_size - left_size - right_size) / middle_size); //middle
    }
}

fn map_uv(uv: vec2<f32>) -> vec2<f32> {
    let src_pos = uv * scale9.src_size;
    let dst_x = map_scale9_1d(src_pos.x, scale9.src_size.x, scale9.dst_size.x, scale9.scale9_rect.x, scale9.scale9_rect.y);
    let dst_y = map_scale9_1d(src_pos.y, scale9.src_size.y, scale9.dst_size.y, scale9.scale9_rect.z, scale9.scale9_rect.w);
    return vec2<f32>(dst_x / scale9.src_size.x, dst_y / scale9.src_size.y);
}

fn get_debug_color(uv: vec2<f32>) -> vec4<f32> {
    let src_pos = uv * scale9.src_size;
    
    // Define the 9 regions based on scale9_rect
    let left_edge = scale9.scale9_rect.x;
    let right_edge = scale9.scale9_rect.y;
    let top_edge = scale9.scale9_rect.z;
    let bottom_edge = scale9.scale9_rect.w;
    
    // Check which region this pixel belongs to
    if (src_pos.x < left_edge) {
        if (src_pos.y < top_edge) {
            return vec4<f32>(1.0, 0.0, 0.0, 0.5); // Top-left: Red
        } else if (src_pos.y > bottom_edge) {
            return vec4<f32>(0.0, 1.0, 0.0, 0.5); // Bottom-left: Green
        } else {
            return vec4<f32>(0.0, 0.0, 1.0, 0.5); // Left: Blue
        }
    } else if (src_pos.x > right_edge) {
        if (src_pos.y < top_edge) {
            return vec4<f32>(1.0, 1.0, 0.0, 0.5); // Top-right: Yellow
        } else if (src_pos.y > bottom_edge) {
            return vec4<f32>(1.0, 0.0, 1.0, 0.5); // Bottom-right: Magenta
        } else {
            return vec4<f32>(0.0, 1.0, 1.0, 0.5); // Right: Cyan
        }
    } else {
        if (src_pos.y < top_edge) {
            return vec4<f32>(0.5, 0.5, 0.0, 0.5); // Top: Olive
        } else if (src_pos.y > bottom_edge) {
            return vec4<f32>(0.5, 0.0, 0.5, 0.5); // Bottom: Purple
        } else {
            return vec4<f32>(0.8, 0.8, 0.8, 0.5); // Center: Light Gray
        }
    }
}

@fragment
fn main_fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    // Get the original texture color
    let original_color: vec4<f32> = textureSample(texture, texture_sampler, map_uv(in.uv));
    
    // Get debug color for the region
    let debug_color: vec4<f32> = get_debug_color(in.uv);
    
    // Blend original texture with debug colors for visualization
    var final_color = mix(original_color, debug_color, 0.3);
    
    if (final_color.a > 0.0) {
        final_color = vec4<f32>(final_color.rgb / final_color.a, final_color.a);
        final_color = final_color * transforms.mult_color + transforms.add_color;
        final_color = saturate(final_color);
        final_color = vec4<f32>(final_color.rgb * final_color.a, final_color.a);
    }

    return final_color;
}