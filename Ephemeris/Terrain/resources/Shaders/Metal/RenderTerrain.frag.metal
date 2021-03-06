/*
* Copyright (c) 2018-2019 Confetti Interactive Inc.
*
* This is a part of Ephemeris.
* This file(code) is licensed under a Creative Commons Attribution-NonCommercial 4.0 International License (https://creativecommons.org/licenses/by-nc/4.0/legalcode) Based on a work at https://github.com/ConfettiFX/The-Forge.
* You may not use the material for commercial purposes.
*
*/

#include <metal_stdlib>
using namespace metal;

inline float3x3 matrix_ctor(float4x4 m)
{
        return float3x3(m[0].xyz, m[1].xyz, m[2].xyz);
}
struct Fragment_Shader
{
    struct Uniforms_RenderTerrainUniformBuffer
    {
        float4x4 projView;
        float4 TerrainInfo;
        float4 CameraInfo;
    };
    constant Uniforms_RenderTerrainUniformBuffer & RenderTerrainUniformBuffer;
    texture2d<float> NormalMap;
    texture2d<float> MaskMap;
    const array<texture2d<float>, 5> tileTextures;
    const array<texture2d<float>, 5> tileTexturesNrm;
    texture2d<float> shadowMap;
    sampler g_LinearMirror;
    sampler g_LinearWrap;
    sampler g_LinearBorder;
    struct PsIn
    {
        float4 position [[position]];
        float3 positionWS [[sample_perspective]];
        float2 texcoord;
        float3 normal;
        float3 tangent;
        float3 bitangent;
    };
    struct PsOut
    {
        float4 albedo [[color(0)]];
        float4 normal [[color(1)]];
    };
    float DepthLinearization(float depth, float near, float far)
    {
        return (((float)(2.0) * near) / ((far + near) - (depth * (far - near))));
    };

    float3 ReconstructNormal(float4 sampleNormal, float intensity)
    {
        float3 tangentNormal;
        tangentNormal.xy = (sampleNormal.rg * 2 - 1) * intensity;
        tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
        return tangentNormal;
    }

    PsOut main(PsIn In)
    {
        PsOut Out;
        float linearDepth = DepthLinearization(((In).position).z, (RenderTerrainUniformBuffer.CameraInfo).x, (RenderTerrainUniformBuffer.CameraInfo).y);
        float dist = distance((RenderTerrainUniformBuffer.CameraInfo).xyz, (In).positionWS);
        (dist = (dist / (RenderTerrainUniformBuffer.CameraInfo).w));
        float lod = 4.0;
        float4 maskVal = MaskMap.sample(g_LinearMirror, (In).texcoord, level(0.0));
        float baseWeight = saturate(((float)(1) - dot(maskVal, float4(1, 1, 1, 1))));
        float baseTileScale = 70;
        float4 tileScale = float4(100, 120, 80, 80);
        float3 result = float3(0, 0, 0);
        float3 surfaceNrm = (float3)(0);
        for (uint i = 0; (i < (uint)(4)); (++i))
        {
            (result += (float3)(tileTextures[i].sample(g_LinearWrap, ((In).texcoord * (float2)(tileScale[i])), level(lod)).xyz * (float3)(maskVal[i])));
            //(surfaceNrm += ((float3)(tileTexturesNrm[i].sample(g_LinearWrap, ((In).texcoord * (float2)(tileScale[i])), level(lod)).xyz * (float3)(2) - (float3)(1)) * (float3)(maskVal[i])));
            surfaceNrm += (float3)ReconstructNormal(tileTexturesNrm[i].sample(g_LinearWrap, In.texcoord * (float2)tileScale[i],  level(lod)), 1.0f) * (float3)maskVal[i];
        }
        float3 baseColor = tileTextures[4].sample(g_LinearWrap, ((In).texcoord * (float2)(baseTileScale)), level(lod)).xyz * (float3)(baseWeight);
        (result += baseColor);
        //(surfaceNrm += (float3)(tileTexturesNrm[4].sample(g_LinearWrap, ((In).texcoord * (float2)(baseTileScale)), level(lod)).xyz * (float3)(baseWeight)));
        surfaceNrm += (float3)ReconstructNormal(tileTexturesNrm[4].sample(g_LinearWrap, In.texcoord * baseTileScale,  level(lod)), 1.0f) * (float3)baseWeight;
        float3 EarthNormal = normalize((In).normal);
        float3 EarthTangent = normalize((In).tangent);
        float3 EarthBitangent = normalize((In).bitangent);
        float3 f3TerrainNormal;
        if (((RenderTerrainUniformBuffer.TerrainInfo).y > 0.5))
        {
            ((f3TerrainNormal).xzy = (float3)(NormalMap.sample(g_LinearMirror, ((In).texcoord).xy, level(0.0)).xyz * (float3)(2) - (float3)(1)));
            float2 f2XZSign = sign(((float2)(0.5) - fract((((In).texcoord).xy / (float2)(2)))));
            ((f3TerrainNormal).xz *= (f2XZSign * (float2)(0.1)));
            ((f3TerrainNormal).y /= (RenderTerrainUniformBuffer.TerrainInfo).z);
        }
        else
        {
            ((f3TerrainNormal).xz = (float2)(NormalMap.sample(g_LinearMirror, ((In).texcoord).xy, level(0.0)).xy));
            float2 f2XZSign = sign(((float2)(0.5) - fract((((In).texcoord).xy / (float2)(2)))));
            ((f3TerrainNormal).xz *= f2XZSign);
            ((f3TerrainNormal).y = (sqrt(saturate(((float)(1) - dot((f3TerrainNormal).xz, (f3TerrainNormal).xz)))) / (RenderTerrainUniformBuffer.TerrainInfo).z));
        }
        (f3TerrainNormal = normalize(((f3TerrainNormal)*(float3x3(EarthTangent, EarthNormal, (-EarthBitangent))))));
        float3 f3TerrainTangent, f3TerrainBitangent;
        (f3TerrainTangent = normalize(cross(f3TerrainNormal, float3(0, 0, 1))));
        (f3TerrainBitangent = normalize(cross(f3TerrainTangent, f3TerrainNormal)));
        (f3TerrainNormal = normalize((((surfaceNrm).xzy)*(float3x3(f3TerrainTangent, f3TerrainNormal, (-f3TerrainBitangent))))));
        ((Out).albedo = float4(result, 1.0));
        ((Out).normal = float4(f3TerrainNormal, 1));
        return Out;
    };

    Fragment_Shader(constant Uniforms_RenderTerrainUniformBuffer & RenderTerrainUniformBuffer,
					texture2d<float> NormalMap,
					texture2d<float> MaskMap,
					const array<texture2d<float>, 5> tileTextures,
					const array<texture2d<float>, 5> tileTexturesNrm,
					texture2d<float> shadowMap,
					sampler g_LinearMirror,
					sampler g_LinearWrap,
					sampler g_LinearBorder) :
RenderTerrainUniformBuffer(RenderTerrainUniformBuffer),NormalMap(NormalMap),MaskMap(MaskMap),tileTextures(tileTextures),tileTexturesNrm(tileTexturesNrm),shadowMap(shadowMap),g_LinearMirror(g_LinearMirror),g_LinearWrap(g_LinearWrap),g_LinearBorder(g_LinearBorder) {}
};

struct ArgsData
{
    texture2d<float> NormalMap;
    texture2d<float> MaskMap;
    const array<texture2d<float>, 5> tileTextures;
    const array<texture2d<float>, 5> tileTexturesNrm;
    texture2d<float> shadowMap;
    sampler g_LinearMirror;
    sampler g_LinearWrap;
    sampler g_LinearBorder;
};

struct ArgsPerFrame
{
    constant Fragment_Shader::Uniforms_RenderTerrainUniformBuffer & RenderTerrainUniformBuffer;
};

fragment Fragment_Shader::PsOut stageMain(
    Fragment_Shader::PsIn In [[stage_in]],
    constant ArgsData& argBufferStatic [[buffer(UPDATE_FREQ_NONE)]],
    constant ArgsPerFrame& argBufferPerFrame [[buffer(UPDATE_FREQ_PER_FRAME)]]
)
{
    Fragment_Shader::PsIn In0;
    In0.position = float4(In.position.xyz, 1.0 / In.position.w);
    In0.positionWS = In.positionWS;
    In0.texcoord = In.texcoord;
    In0.normal = In.normal;
    In0.tangent = In.tangent;
    In0.bitangent = In.bitangent;
	
    Fragment_Shader main(
    argBufferPerFrame.RenderTerrainUniformBuffer,
    argBufferStatic.NormalMap,
    argBufferStatic.MaskMap,
    argBufferStatic.tileTextures,
    argBufferStatic.tileTexturesNrm,
    argBufferStatic.shadowMap,
    argBufferStatic.g_LinearMirror,
    argBufferStatic.g_LinearWrap,
    argBufferStatic.g_LinearBorder);
	
    return main.main(In0);
}
