#include <metal_stdlib>
#pragma clang diagnostic ignored "-Wparentheses-equality"
using namespace metal;
struct xlatMtlShaderInput {
  float4 gl_FragCoord [[position]];
};

struct xlatMtlShaderOutput {
  float4 gl_FragColor;
};

struct xlatMtlShaderUniform {
  float2 resolution;
  float subtransformSize;
  float normalization;
  bool horizontal;
  bool forward;
};

fragment xlatMtlShaderOutput index_glsl (xlatMtlShaderInput _mtl_i [[stage_in]], constant xlatMtlShaderUniform& _mtl_u [[buffer(0)]]
  ,   texture2d<float> src [[texture(0)]], sampler _mtlsmp_src [[sampler(0)]])
{
  xlatMtlShaderOutput _mtl_o;
  float4 tmpvar_1 = 0;
  float twiddleArgument_2 = 0;
  float evenIndex_3 = 0;
  float index_4 = 0;
  float2 oddPos_5 = 0;
  float2 evenPos_6 = 0;
  float tmpvar_7 = 0;
  if (_mtl_u.horizontal) {
    tmpvar_7 = _mtl_i.gl_FragCoord.x;
  } else {
    tmpvar_7 = _mtl_i.gl_FragCoord.y;
  };
  index_4 = (tmpvar_7 - 0.5);
  float tmpvar_8 = 0;
  tmpvar_8 = (_mtl_u.subtransformSize * 0.5);
  evenIndex_3 = (((
    floor((index_4 / _mtl_u.subtransformSize))
   * tmpvar_8) + (float(fmod (index_4, tmpvar_8)))) + 0.5);
  if (_mtl_u.horizontal) {
    float2 tmpvar_9 = 0;
    tmpvar_9.x = evenIndex_3;
    tmpvar_9.y = _mtl_i.gl_FragCoord.y;
    evenPos_6 = tmpvar_9;
    float2 tmpvar_10 = 0;
    tmpvar_10.x = evenIndex_3;
    tmpvar_10.y = _mtl_i.gl_FragCoord.y;
    oddPos_5 = tmpvar_10;
  } else {
    float2 tmpvar_11 = 0;
    tmpvar_11.x = _mtl_i.gl_FragCoord.x;
    tmpvar_11.y = evenIndex_3;
    evenPos_6 = tmpvar_11;
    float2 tmpvar_12 = 0;
    tmpvar_12.x = _mtl_i.gl_FragCoord.x;
    tmpvar_12.y = evenIndex_3;
    oddPos_5 = tmpvar_12;
  };
  evenPos_6 = (evenPos_6 * _mtl_u.resolution);
  oddPos_5 = (oddPos_5 * _mtl_u.resolution);
  if (_mtl_u.horizontal) {
    oddPos_5.x = (oddPos_5.x + 0.5);
  } else {
    oddPos_5.y = (oddPos_5.y + 0.5);
  };
  float4 tmpvar_13 = 0;
  tmpvar_13 = src.sample(_mtlsmp_src, float2((evenPos_6).x, (1.0 - (evenPos_6).y)));
  float4 tmpvar_14 = 0;
  tmpvar_14 = src.sample(_mtlsmp_src, float2((oddPos_5).x, (1.0 - (oddPos_5).y)));
  float tmpvar_15 = 0;
  if (_mtl_u.forward) {
    tmpvar_15 = 6.283185;
  } else {
    tmpvar_15 = -6.283185;
  };
  twiddleArgument_2 = (tmpvar_15 * (index_4 / _mtl_u.subtransformSize));
  float tmpvar_16 = 0;
  tmpvar_16 = cos(twiddleArgument_2);
  float tmpvar_17 = 0;
  tmpvar_17 = sin(twiddleArgument_2);
  float4 tmpvar_18 = 0;
  tmpvar_18.xy = ((tmpvar_16 * (float2)(tmpvar_14.xz)) - (tmpvar_17 * (float2)(tmpvar_14.yw)));
  tmpvar_18.zw = ((tmpvar_17 * (float2)(tmpvar_14.xz)) + (tmpvar_16 * (float2)(tmpvar_14.yw)));
  tmpvar_1 = (((float4)(tmpvar_13) + tmpvar_18.xzyw) * _mtl_u.normalization);
  _mtl_o.gl_FragColor = tmpvar_1;
  return _mtl_o;
}



