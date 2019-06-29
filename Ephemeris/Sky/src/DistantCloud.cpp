/*
* Copyright (c) 2018-2019 Confetti Interactive Inc.
*
* This is a part of Ephemeris.
* This file(code) is licensed under a Creative Commons Attribution-NonCommercial 4.0 International License (https://creativecommons.org/licenses/by-nc/4.0/legalcode) Based on a work at https://github.com/ConfettiFX/The-Forge.
* You may not use the material for commercial purposes.
*
*/

#pragma once

#include "DistantCloud.h"

DistantCloud::DistantCloud(const mat4 &Transform, Texture* tex):
	m_Transform(Transform), m_Texture(tex)
{
}

DistantCloud::~DistantCloud(void)
{
}

void DistantCloud::moveCloud(const vec3 direction)
{
  float temp = m_Transform.getRow(0).getW();
  temp += direction.getX();
  temp += direction.getY();
  temp += direction.getZ();

  //vec4 &row0 = m_Transform.getRow(0).setW();
  m_Transform[3][0] += temp;

}
