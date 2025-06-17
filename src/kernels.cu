#pragma once

#include <cstdint>
#include <cfloat>
#include <cmath>

#include "geometry.cu"

// constants for matrix transformation
__constant__ float c_rotation_matrix[16];
__constant__ float c_view_matrix[16];
__constant__ float c_proj_matrix[16];

// constants for ray-tracing
__constant__ float c_camera_pos[3];
__constant__ float c_camera_forward[3];
__constant__ float c_camera_right[3];
__constant__ float c_camera_up[3];
__constant__ float c_camera_fov;
__constant__ float c_camera_aspect;

// CUDA kernel for ray generation, triangle shading, and visible light‐sphere overlay
__global__ void ray_trace_kernel(uint32_t *pixels,
                                 int width,
                                 int height,
                                 const Triangle *triangles,
                                 int num_triangles)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height)
        return;

    // generate primary ray
    float u = (2.0f * (x + 0.5f) / width - 1.0f) * c_camera_aspect;
    float v = 1.0f - 2.0f * (y + 0.5f) / height;
    float fov_scale = tanf(c_camera_fov * 0.5f * M_PI / 180.0f);
    u *= fov_scale;
    v *= fov_scale;

    vec3 cam_pos = vec3(c_camera_pos[0],
                        c_camera_pos[1],
                        c_camera_pos[2]);
    vec3 cam_forward = vec3(c_camera_forward[0],
                            c_camera_forward[1],
                            c_camera_forward[2]);
    vec3 cam_right = vec3(c_camera_right[0],
                          c_camera_right[1],
                          c_camera_right[2]);
    vec3 cam_up = vec3(c_camera_up[0],
                       c_camera_up[1],
                       c_camera_up[2]);

    vec3 dir = (cam_forward + cam_right * u + cam_up * v).normalize();
    Ray ray(cam_pos, dir);

    // find closest triangle intersection
    HitInfo closest_hit;
    for (int i = 0; i < num_triangles; i++)
    {
        float t;
        vec3 hp, hn;
        if (ray_triangle_intersect(ray, triangles[i], t, hp, hn))
        {
            if (t > 0.001f && t < closest_hit.t)
            {
                closest_hit.hit = true;
                closest_hit.t = t;
                closest_hit.point = hp;
                closest_hit.normal = hn;
                closest_hit.triangle_id = i;
            }
        }
    }

    // bg color
    uint32_t color = 0xFFFFFFFF;

    // shade if hit
    if (closest_hit.hit)
    {
        vec3 light_pos = vec3(2.0f, 3.0f, 2.0f);
        vec3 L = (light_pos - closest_hit.point).normalize();
        float light_d = (light_pos - closest_hit.point).length();
        float ndotl = fmaxf(0.0f, closest_hit.normal.dot(L));

        bool in_shadow = shadow_ray_test(closest_hit.point,
                                         L,
                                         light_d,
                                         closest_hit.normal,
                                         triangles,
                                         num_triangles);

        float intensity;
        if (in_shadow)
        {
            intensity = 0.3f; // ambient only
        }
        else
        {
            intensity = 0.2f + ndotl * 0.6f;
        }
        intensity = fminf(intensity, 0.8f);

        int gray = (int)((1.0f - intensity) * 255.0f);
        gray = max(0, min(255, gray));

        color = (gray << 24) | (gray << 16) | (gray << 8) | 0xFF;
    }

    // visible light sphere
    vec3 light_pos = vec3(2.0f, 3.0f, 2.0f);
    float light_radius = 1.0f;

    vec3 oc = ray.origin - light_pos;
    float A = ray.direction.dot(ray.direction);
    float B = 2.0f * oc.dot(ray.direction);
    float C = oc.dot(oc) - light_radius * light_radius;
    float D = B * B - 4.0f * A * C;

    if (D >= 0.0f)
    {
        float t_sphere = (-B - sqrtf(D)) / (2.0f * A);
        float tri_t = closest_hit.hit ? closest_hit.t : FLT_MAX;

        if (t_sphere > 0.001f && t_sphere < tri_t)
        {

            color = 0xFF000000;
        }
    }

    // write to output
    pixels[y * width + x] = color;
}