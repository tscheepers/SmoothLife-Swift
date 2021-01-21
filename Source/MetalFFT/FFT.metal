#include <metal_stdlib>
using namespace metal;

constant float TWOPI = 6.283185307179586;

struct Params {
    float2 resolution;
    float subtransformSize;
    float normalization;
    bool horizontal;
    bool forward;
};

kernel void fft(constant Params& params [[buffer(0)]],
                texture2d<float, access::sample> current [[texture(0)]],
                texture2d<float, access::write> next [[texture(1)]],
                uint2 gid [[ thread_position_in_grid ]])
{
    float2 evenPos, oddPos, twiddle;
    float index, evenIndex, twiddleArgument;
    float4 even, odd, result;
    float x = float(gid.x);
    float y = float(gid.y);

    index = (params.horizontal ? x : y);
    evenIndex = floor(index / params.subtransformSize) * (params.subtransformSize * 0.5) + fmod(index, params.subtransformSize * 0.5) + 0.5;

    if (params.horizontal) {
        evenPos = float2(evenIndex, y) * params.resolution;
        oddPos = float2(evenIndex, y) * params.resolution;
        oddPos.x += 0.5;
    } else {
        evenPos = float2(x, evenIndex) * params.resolution;
        oddPos = float2(x, evenIndex) * params.resolution;
        oddPos.y += 0.5;
    }

    constexpr sampler smplr(coord::normalized,
                            address::repeat,
                            filter::nearest);

    even = current.sample(smplr, evenPos);
    odd = current.sample(smplr, oddPos);

    twiddleArgument = (params.forward ? -TWOPI : TWOPI) * (index / params.subtransformSize);
    twiddle = float2(cos(twiddleArgument), sin(twiddleArgument));

    result = (even.rgba + float4(
        twiddle.x * odd.xz - twiddle.y * odd.yw,
        twiddle.y * odd.xz + twiddle.x * odd.yw
    ).xzyw);

    next.write(result, gid);
}
