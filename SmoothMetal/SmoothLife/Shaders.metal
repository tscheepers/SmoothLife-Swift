#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float2 uv;
};

vertex Vertex sl_vertex_shader(constant float4 *vertices [[buffer(0)]],
                               uint id [[vertex_id]])
{
    return {
        .position = vertices[id],
        .uv = (vertices[id].xy + float2(1)) / float2(2)
    };
}

fragment float4 sl_fragment_shader(Vertex vtx [[stage_in]],
                                   texture2d<float> generation [[texture(0)]])
{
    constexpr sampler smplr(coord::normalized,
                            address::clamp_to_zero,
                            filter::nearest);
    uint cell = generation.sample(smplr, vtx.uv).r;
    return float4(cell);
}

constant float B1 = 0.254;
constant float B2 = 0.312;
constant float D1 = 0.340;
constant float D2 = 0.518;
constant float DT = 0.1;

float hard_step(float x, float a)
{
    if (x >= a) {
        return 1.0;
    } else {
        return 0.0;
    }
}

float sigmoid_mix(float x, float y, float m)
{
    return x * (1.0 - hard_step(m, 0.5)) + y * hard_step(m, 0.5);
}

float sigmoid_ab(float x, float a, float b)
{
    return hard_step(x, a) * (1.0 - hard_step(x, b));
}

kernel void sl_compute_shader(texture2d<float, access::read> m [[texture(0)]],
                              texture2d<float, access::read> n [[texture(1)]],
                              texture2d<float, access::read> current [[texture(2)]],
                              texture2d<float, access::write> next [[texture(3)]],
                              uint2 index [[thread_position_in_grid]])
{

    //next.write(g, index);

    float f = sigmoid_mix(
        sigmoid_ab(n.read(index).r, B1, B2),
        sigmoid_ab(n.read(index).r, D1, D2),
        m.read(index).r
    );

    float g = current.read(index).r;

    next.write(clamp(f, 0.0, 1.0), index);
}


