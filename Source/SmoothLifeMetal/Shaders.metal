#include <metal_stdlib>
using namespace metal;

struct TransitionParams {
    float b1;
    float b2;
    float d1;
    float d2;
    float dt;
};

float hard_step(float value, float boundary) {
    if (value > boundary) {
        return 1.0;
    } else {
        return 0.0;
    }
}

float sigma(float birth, float death, float m) {
    return birth * (1.0 - hard_step(m, 0.5)) + death * hard_step(m, 0.5);
}

float sigma_interval(float n, float i1, float i2)
{
    return hard_step(n, i1) * (1.0 - hard_step(n, i2));
}

float clamp(float value) {
    if (value < 0.0) {
        return 0.0;
    } else if (value > 1.0) {
        return 1.0;
    }
    return value;
}

kernel void transition(constant TransitionParams& params [[buffer(0)]],
                       texture2d<float, access::read> effective_cell [[texture(0)]],
                       texture2d<float, access::read> neightborhood [[texture(1)]],
                       texture2d<float, access::read> field [[texture(2)]],
                       texture2d<float, access::write> next [[texture(3)]],
                       uint2 gid [[ thread_position_in_grid ]])
{
    float m = effective_cell.read(gid).r;
    float n = neightborhood.read(gid).r;

    float s = sigma(sigma_interval(n, params.b1, params.b2), sigma_interval(n, params.d1, params.d2), m);

    float g = field.read(gid).r;

    float4 result = float4(clamp(g + params.dt * (s - g)), 0.0, 0.0, 1.0);

    next.write(result, gid);
}


kernel void complex_multiplication(texture2d<float, access::read> lhs [[texture(0)]],
                                   texture2d<float, access::read> rhs [[texture(1)]],
                                   texture2d<float, access::write> result [[texture(2)]],
                                   uint2 gid [[ thread_position_in_grid ]])
{
    float4 left = lhs.read(gid);
    float4 right = rhs.read(gid);

    float4 multiplied = float4(left.x * right.x - left.y * right.y,
                               left.y * right.x + left.x * right.y,
                               0, 0);

    result.write(multiplied, gid);
}
