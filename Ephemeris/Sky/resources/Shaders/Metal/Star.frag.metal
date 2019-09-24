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

struct Uniforms_StarUniform
{
	float4x4 RotMat;
	float4x4 ViewProjMat;
	float4 LightDirection;
	float4 Dx;
	float4 Dy;
};

struct PsIn
{
	float4 position [[position]];
	float3 texCoord;
	float2 screenCoord;
	float3 color;
};

struct ArgsData
{
	texture2d<float> depthTexture;
    sampler g_LinearBorder;
};

struct ArgsPerFrame
{
	constant Uniforms_StarUniform & StarUniform;
};

fragment float4 stageMain(PsIn In [[stage_in]],
	constant ArgsData& argBufferStatic [[buffer(UPDATE_FREQ_NONE)]],
    constant ArgsPerFrame& argBufferPerFrame [[buffer(UPDATE_FREQ_PER_FRAME)]]
)
{
	float2 screenUV = (In).screenCoord;
    float sceneDepth = argBufferStatic.depthTexture.sample(argBufferStatic.g_LinearBorder, screenUV, level(0)).r;
	if(sceneDepth < 1.0)
		discard_fragment();

	float x = 1.0 - abs(In.texCoord.x);
	float x2 = x*x;
	float x4 = x2*x2;
	float x8 = x4*x2;
	float y = 1.0 - abs(In.texCoord.y);
	float y2 = y*y;
	float y4 = y2*y2;
	float y8 = y4*y2;

	float Mask = max( x8 * y8, 0.0);
	float alpha = saturate(saturate(-argBufferPerFrame.StarUniform.LightDirection.y + 0.2f) * 2.0f);

	
	return float4(In.color, Mask *alpha);
	
}
