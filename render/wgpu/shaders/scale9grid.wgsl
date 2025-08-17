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
    let uv = (mat3x3<f32>(matrix_[0].xyz, matrix_[1].xyz, matrix_[2].xyz) * vec3<f32>(in.position, 1.0)).xy;
    let pos = common__globals.view_matrix * transforms.world_matrix * vec4<f32>(in.position.x, in.position.y, 0.0, 1.0);
    return VertexOutput(pos, uv);
}

@fragment
fn main_fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    // Sample the texture
    var color: vec4<f32> = textureSample(texture, texture_sampler, in.uv);
    
    // Apply color transform like the bitmap shader
    if (color.a > 0.0) {
        color = vec4<f32>(color.rgb / color.a, color.a);
        color = color * transforms.mult_color + transforms.add_color;
        color = saturate(color);
        color = vec4<f32>(color.rgb * color.a, color.a);
    }
    
    // DEBUG: Draw the 9-slice grid boundaries
    let uv_x = in.uv.x;
    let uv_y = in.uv.y;
    
    // The UV coordinates are already in texture space (0.0 to 1.0)
    // We need to convert them to the actual texture dimensions
    let src_x = uv_x * scale9.src_size.x;
    let src_y = uv_y * scale9.src_size.y;
    
    // Define the 9-slice regions
    let left = scale9.scale9_rect.x;      // x_min
    let right = scale9.scale9_rect.y;     // x_max  
    let top = scale9.scale9_rect.z;       // y_min
    let bottom = scale9.scale9_rect.w;    // y_max
    
    // Draw grid lines with thicker lines for better visibility
    let line_width = 4.0;
    let is_vertical_line = abs(src_x - left) < line_width || abs(src_x - right) < line_width;
    let is_horizontal_line = abs(src_y - top) < line_width || abs(src_y - bottom) < line_width;
    
    if (is_vertical_line || is_horizontal_line) {
        // Draw grid lines in bright red
        color = vec4<f32>(1.0, 0.0, 0.0, 1.0);
    }
    
    return color;
}