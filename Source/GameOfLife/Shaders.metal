#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float2 uv;
};

vertex Vertex gol_vertex_shader(constant float4 *vertices [[buffer(0)]],
                                uint id [[vertex_id]])
{
    return {
        .position = vertices[id],
        .uv = (vertices[id].xy + float2(1)) / float2(2)
    };
}

fragment float4 gol_fragment_shader(Vertex vtx [[stage_in]],
                                    texture2d<uint> current [[texture(0)]])
{
    constexpr sampler smplr(coord::normalized,
                          address::clamp_to_zero,
                          filter::nearest);
    uint cell = current.sample(smplr, vtx.uv).r;
    return float4(cell);
}

kernel void gol_compute_shader(texture2d<uint, access::read> current [[texture(0)]],
                           texture2d<uint, access::write> next [[texture(1)]],
                           uint2 index [[ thread_position_in_grid ]])
{
    short neighbours = 0;

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            if (i == 0 && j == 0) {
                continue;
            }
            uint2 neighbour = index + uint2(i, j);
            if (current.read(neighbour).r == 1) {
                neighbours++;
            }
        }
    }

    if (current.read(index).r == 1) {
        if (neighbours < 2 || neighbours > 3) {
          next.write(0, index);
        } else {
          next.write(1, index);
        }
    } else {
        if (neighbours == 3) {
          next.write(1, index);
        } else {
          next.write(0, index);
        }
    }
}
