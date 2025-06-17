#pragma once

#include "geometry.cu"
#include "kernels.cu"
#include "utils.cu"

struct Camera
{
    vec3 position;
    vec3 target;
    vec3 up;
    float fov;
    float aspect;
    float near_plane;
    float far_plane;

    Camera(int width, int height)
        : position(0, 0, 8), target(0, 0, 0), up(0, 1, 0),
          fov(45.0f), aspect(float(width) / height), near_plane(0.1f), far_plane(100.0f) {}
};

Camera camera(800, 600);
float zoom = 1.0f;

float rotation_x = 0.0f;
float rotation_y = 0.0f;

void update_transformation_matrices()
{
    // rotation matrix
    float cx = cosf(rotation_x), sx = sinf(rotation_x);
    float cy = cosf(rotation_y), sy = sinf(rotation_y);

    float rotation_matrix[16] = {
        cy, 0, sy, 0,
        sx * sy, cx, -sx * cy, 0,
        -cx * sy, sx, cx * cy, 0,
        0, 0, 0, 1};

    CUDA_CHECK(cudaMemcpyToSymbol(c_rotation_matrix, rotation_matrix, sizeof(rotation_matrix)));

    // view matrix
    vec3 zoom_position = camera.position * zoom;

    vec3 forward = (camera.target - zoom_position).normalize();
    vec3 right = vec3(forward.y * camera.up.z - forward.z * camera.up.y,
                      forward.z * camera.up.x - forward.x * camera.up.z,
                      forward.x * camera.up.y - forward.y * camera.up.x)
                     .normalize();
    vec3 up = vec3(right.y * forward.z - right.z * forward.y,
                   right.z * forward.x - right.x * forward.z,
                   right.x * forward.y - right.y * forward.x);

    float view_matrix[16] = {
        right.x, right.y, right.z, -(right.x * camera.position.x + right.y * camera.position.y + right.z * camera.position.z),
        up.x, up.y, up.z, -(up.x * camera.position.x + up.y * camera.position.y + up.z * camera.position.z),
        -forward.x, -forward.y, -forward.z, forward.x * camera.position.x + forward.y * camera.position.y + forward.z * camera.position.z,
        0, 0, 0, 1};

    CUDA_CHECK(cudaMemcpyToSymbol(c_view_matrix, view_matrix, sizeof(view_matrix)));

    // projection matrix
    float f = 1.0f / tanf(camera.fov * 0.5f * (float)M_PI / 180.0f);
    float range = camera.far_plane - camera.near_plane;

    float proj_matrix[16] = {
        f / camera.aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, -(camera.far_plane + camera.near_plane) / range, -2 * camera.far_plane * camera.near_plane / range,
        0, 0, -1, 0};

    CUDA_CHECK(cudaMemcpyToSymbol(c_proj_matrix, proj_matrix, sizeof(proj_matrix)));

    // update camera constants for ray tracing
    float cam_pos[3] = {zoom_position.x, zoom_position.y, zoom_position.z};
    float cam_forward[3] = {forward.x, forward.y, forward.z};
    float cam_right[3] = {right.x, right.y, right.z};
    float cam_up[3] = {up.x, up.y, up.z};

    CUDA_CHECK(cudaMemcpyToSymbol(c_camera_pos, cam_pos, sizeof(cam_pos)));
    CUDA_CHECK(cudaMemcpyToSymbol(c_camera_forward, cam_forward, sizeof(cam_forward)));
    CUDA_CHECK(cudaMemcpyToSymbol(c_camera_right, cam_right, sizeof(cam_right)));
    CUDA_CHECK(cudaMemcpyToSymbol(c_camera_up, cam_up, sizeof(cam_up)));
    CUDA_CHECK(cudaMemcpyToSymbol(c_camera_fov, &camera.fov, sizeof(camera.fov)));
    CUDA_CHECK(cudaMemcpyToSymbol(c_camera_aspect, &camera.aspect, sizeof(camera.aspect)));
}
