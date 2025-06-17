#pragma once

#include <iostream>
#include <vector>
#include <algorithm>
#include <cmath>

#include "geometry.cu"
#include "kernels.cu"
#include "utils.cu"
#include "camera.cu"

using namespace std;

void draw_line(vector<uint32_t> &pixels, int width, int height,
               int x0, int y0, int x1, int y1, uint32_t color)
{
    // Same line drawing as main2.cu
    int dx = abs(x1 - x0);
    int dy = abs(y1 - y0);
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (true)
    {
        if (x0 >= 0 && x0 < width && y0 >= 0 && y0 < height)
        {
            pixels[y0 * width + x0] = color;
        }

        if (x0 == x1 && y0 == y1)
            break;

        int e2 = 2 * err;
        if (e2 > -dy)
        {
            err -= dy;
            x0 += sx;
        }
        if (e2 < dx)
        {
            err += dx;
            y0 += sy;
        }
    }
}

void apply_rotation_to_triangles()
{
    // Apply rotation to triangles for ray tracing
    float cx = cosf(rotation_x), sx = sinf(rotation_x);
    float cy = cosf(rotation_y), sy = sinf(rotation_y);

    float rotation_matrix[16] = {
        cy, 0, sy, 0,
        sx * sy, cx, -sx * cy, 0,
        -cx * sy, sx, cx * cy, 0,
        0, 0, 0, 1};

    // Reset triangles to original and apply rotation
    triangles = original_triangles;

    for (auto &tri : triangles)
    {
        for (int i = 0; i < 3; i++)
        {
            tri.v[i] = matrix_multiply(rotation_matrix, tri.v[i]);
        }
        // Recalculate normal after rotation
        vec3 edge1 = tri.v[1] - tri.v[0];
        vec3 edge2 = tri.v[2] - tri.v[0];
        tri.normal = edge1.cross(edge2).normalize();
    }
}

void render_ray_traced(vector<uint32_t> &pixels, int width, int height)
{
    if (triangles.empty())
    {
        fill(pixels.begin(), pixels.end(), 0xFFFFFFFF); // White background
        return;
    }

    // Apply current rotation to triangles
    apply_rotation_to_triangles();

    // Update camera constants
    update_transformation_matrices();

    // Allocate device memory for triangles if needed
    if (!d_triangles || current_allocated < triangles.size())
    {
        if (d_triangles)
            CUDA_CHECK(cudaFree(d_triangles));

        CUDA_CHECK(cudaMalloc(&d_triangles, triangles.size() * sizeof(Triangle)));
        current_allocated = triangles.size();
        cout << "Allocated GPU memory for " << triangles.size() << " triangles\n";
    }

    // Allocate device memory for pixels
    if (!d_pixels)
    {
        CUDA_CHECK(cudaMalloc(&d_pixels, width * height * sizeof(uint32_t)));
    }

    // Copy transformed triangles to device
    CUDA_CHECK(cudaMemcpy(d_triangles, triangles.data(), triangles.size() * sizeof(Triangle), cudaMemcpyHostToDevice));

    // Launch ray tracing kernel with optimal block size
    dim3 blockSize(16, 16);
    dim3 gridSize((width + blockSize.x - 1) / blockSize.x, (height + blockSize.y - 1) / blockSize.y);

    ray_trace_kernel<<<gridSize, blockSize>>>(d_pixels, width, height, d_triangles, triangles.size());
    CUDA_CHECK(cudaDeviceSynchronize());

    // Check for kernel errors
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess)
    {
        printf("CUDA ray tracing error: %s\n", cudaGetErrorString(err));
    }

    // Copy result back to host
    CUDA_CHECK(cudaMemcpy(pixels.data(), d_pixels, width * height * sizeof(uint32_t), cudaMemcpyDeviceToHost));
}

// Project 3D point to 2D screen coordinates with proper 3D pipeline (same as main2.cu)
bool project_point(const vec3 &world_pos, int width, int height, int &x, int &y)
{
    // Apply rotation
    float rotation_matrix[16];
    float cx = cosf(rotation_x), sx = sinf(rotation_x);
    float cy = cosf(rotation_y), sy = sinf(rotation_y);

    rotation_matrix[0] = cy;
    rotation_matrix[4] = 0;
    rotation_matrix[8] = sy;
    rotation_matrix[12] = 0;
    rotation_matrix[1] = sx * sy;
    rotation_matrix[5] = cx;
    rotation_matrix[9] = -sx * cy;
    rotation_matrix[13] = 0;
    rotation_matrix[2] = -cx * sy;
    rotation_matrix[6] = sx;
    rotation_matrix[10] = cx * cy;
    rotation_matrix[14] = 0;
    rotation_matrix[3] = 0;
    rotation_matrix[7] = 0;
    rotation_matrix[11] = 0;
    rotation_matrix[15] = 1;

    vec3 rotated = matrix_multiply(rotation_matrix, world_pos);

    vec3 zoom_position = camera.position * zoom;

    // Apply view transformation
    vec3 forward = (camera.target - zoom_position).normalize();
    vec3 right = vec3(forward.y * camera.up.z - forward.z * camera.up.y,
                      forward.z * camera.up.x - forward.x * camera.up.z,
                      forward.x * camera.up.y - forward.y * camera.up.x)
                     .normalize();
    vec3 up = vec3(right.y * forward.z - right.z * forward.y,
                   right.z * forward.x - right.x * forward.z,
                   right.x * forward.y - right.y * forward.x);

    float view_matrix[16];
    view_matrix[0] = right.x;
    view_matrix[4] = right.y;
    view_matrix[8] = right.z;
    view_matrix[12] = -(right.x * zoom_position.x + right.y * zoom_position.y + right.z * zoom_position.z);
    view_matrix[13] = -(up.x * zoom_position.x + up.y * zoom_position.y + up.z * zoom_position.z);
    view_matrix[14] = forward.x * zoom_position.x + forward.y * zoom_position.y + forward.z * zoom_position.z;
    view_matrix[1] = up.x;
    view_matrix[5] = up.y;
    view_matrix[9] = up.z;
    view_matrix[2] = -forward.x;
    view_matrix[6] = -forward.y;
    view_matrix[10] = -forward.z;
    view_matrix[3] = 0;
    view_matrix[7] = 0;
    view_matrix[11] = 0;
    view_matrix[15] = 1;

    vec3 view_pos = matrix_multiply(view_matrix, rotated);

    // Apply projection
    float f = 1.0f / tanf(camera.fov * 0.5f * (float)M_PI / 180.0f);
    float range = camera.far_plane - camera.near_plane;

    float proj_matrix[16];
    proj_matrix[0] = f / camera.aspect;
    proj_matrix[4] = 0;
    proj_matrix[8] = 0;
    proj_matrix[12] = 0;
    proj_matrix[1] = 0;
    proj_matrix[5] = f;
    proj_matrix[9] = 0;
    proj_matrix[13] = 0;
    proj_matrix[2] = 0;
    proj_matrix[6] = 0;
    proj_matrix[10] = -(camera.far_plane + camera.near_plane) / range;
    proj_matrix[14] = -2 * camera.far_plane * camera.near_plane / range;
    proj_matrix[3] = 0;
    proj_matrix[7] = 0;
    proj_matrix[11] = -1;
    proj_matrix[15] = 0;

    vec3 clip_pos = matrix_multiply(proj_matrix, view_pos);

    // Check if behind camera
    if (clip_pos.z < -1.0f || clip_pos.z > 1.0f)
        return false;

    // Convert to screen coordinates
    x = static_cast<int>((clip_pos.x + 1.0f) * 0.5f * width);
    y = static_cast<int>((1.0f - clip_pos.y) * 0.5f * height);

    return (x >= -100 && x < width + 100 && y >= -100 && y < height + 100);
}