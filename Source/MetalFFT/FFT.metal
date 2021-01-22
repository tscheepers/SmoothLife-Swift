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

kernel void fft(constant Params& params [[buffer(0)]],
                texture2d<float, access::sample> current [[texture(0)]],
                texture2d<float, access::write> next [[texture(1)]],
                uint2 gid [[ thread_position_in_grid ]])
{
    uint index = (params.horizontal ? gid.x : gid.y);
    uint indexOfWindow = (index / params.power) * (params.power / 2);
    uint indexInWindow = index % (params.power / 2);

    uint evenIndex = indexOfWindow + indexInWindow;
    uint oddIndex = evenIndex + (params.dim / 2);

    uint2 evenPos, oddPos;

    if (params.horizontal) {
        evenPos = uint2(evenIndex, gid.y);
        oddPos = uint2(oddIndex, gid.y);
    } else {
        evenPos = uint2(gid.x, evenIndex);
        oddPos = uint2(gid.x, oddIndex);
    }

    float4 odd = current.read(oddPos);

    float twiddle = (params.forward ? -TWO_PI : TWO_PI) * (float(indexInWindow) / float(params.power));
    float2 twiddleComplex = float2(cos(twiddle), sin(twiddle));

    float4 oddMultiplied = float4(twiddleComplex.x * odd.x - twiddleComplex.y * odd.y,
                                  twiddleComplex.y * odd.x + twiddleComplex.x * odd.y,
                                  0, 0);

    float4 even = current.read(evenPos);

    float4 result;
    if (indexInWindow == (index % params.power)) {
        result = (even + oddMultiplied) * params.normalization;
    } else {
        result = (even - oddMultiplied) * params.normalization;
    }

    next.write(result, gid);
}
