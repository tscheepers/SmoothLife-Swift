#include <metal_stdlib>
using namespace metal;

constant float TWO_PI = 6.283185307179586;

struct Params {
    float normalization;
    bool horizontal;
    bool forward;
    uint dim;
    uint power;
};

// Each time this kernel is executed we perform one of the total `log2(dim)` steps in one direction (horizontal or vertical)
kernel void fft(constant Params& params [[buffer(0)]],
                texture2d<float, access::sample> current [[texture(0)]],
                texture2d<float, access::write> next [[texture(1)]],
                uint2 gid [[ thread_position_in_grid ]])
{
    uint idx = (params.horizontal ? gid.x : gid.y);

    uint window_idx = (idx / params.power) * (params.power / 2);
    uint idx_in_window = idx % (params.power / 2);

    uint even_idx = window_idx + idx_in_window;
    uint odd_idx = even_idx + (params.dim / 2);

    uint2 even_coord, odd_coord;

    if (params.horizontal) {
        even_coord = uint2(even_idx, gid.y);
        odd_coord = uint2(odd_idx, gid.y);
    } else {
        even_coord = uint2(gid.x, even_idx);
        odd_coord = uint2(gid.x, odd_idx);
    }

    float4 odd = current.read(odd_coord);

    // Use Euler's formula to convert to a complex number
    float exponent = (params.forward ? -TWO_PI : TWO_PI) * (float(idx_in_window) / float(params.power));
    float2 complex = float2(cos(exponent), sin(exponent));

    float4 odd_multiplied = float4(complex.x * odd.x - complex.y * odd.y,
                                  complex.y * odd.x + complex.x * odd.y,
                                  0, 0);

    float4 even = current.read(even_coord);

    float4 result;
    if (idx_in_window == (idx % params.power)) {
        result = (even + odd_multiplied) * params.normalization;
    } else {
        result = (even - odd_multiplied) * params.normalization;
    }

    next.write(result, gid);
}
