#include <metal_stdlib>
using namespace metal;


const float TWOPI = 6.283185307179586;

float4 fft(sampler src, float2 resolution, float subtransformSize, bool horizontal, bool forward, float normalization);
float4 fft(sampler src, float2 resolution, float subtransformSize, bool horizontal, bool forward, float normalization) {

    float2 evenPos, oddPos, twiddle, outputA, outputB;
    float4 even, odd;
    float index, evenIndex, twiddleArgument;

    index = (horizontal ? gl_FragCoord.x : gl_FragCoord.y) - 0.5;

    evenIndex = floor(index / subtransformSize) * (subtransformSize * 0.5) + mod(index, subtransformSize * 0.5) + 0.5;

    if (horizontal) {
        evenPos = float2(evenIndex, gl_FragCoord.y);
        oddPos = float2(evenIndex, gl_FragCoord.y);
    } else {
        evenPos = float2(gl_FragCoord.x, evenIndex);
        oddPos = float2(gl_FragCoord.x, evenIndex);
    }

    evenPos *= resolution;
    oddPos *= resolution;

    if (horizontal) {
        oddPos.x += 0.5;
    } else {
        oddPos.y += 0.5;
    }

    even = texture2D(src, evenPos);
    odd = texture2D(src, oddPos);

    twiddleArgument = (forward ? TWOPI : -TWOPI) * (index / subtransformSize);
    twiddle = float2(cos(twiddleArgument), sin(twiddleArgument));

    return (even.rgba + float4(
        twiddle.x * odd.xz - twiddle.y * odd.yw,
        twiddle.y * odd.xz + twiddle.x * odd.yw
    ).xzyw) * normalization;
}
