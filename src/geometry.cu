#pragma once

#include <cmath>
#include <cfloat>

struct vec3
{
    float x, y, z;
    __host__ __device__ vec3() : x(0), y(0), z(0) {}
    __host__ __device__ vec3(float xx, float yy, float zz) : x(xx), y(yy), z(zz) {}

    __host__ __device__ vec3 operator+(const vec3 &other) const { return vec3(x + other.x, y + other.y, z + other.z); }
    __host__ __device__ vec3 operator-(const vec3 &other) const { return vec3(x - other.x, y - other.y, z - other.z); }
    __host__ __device__ vec3 operator*(float t) const { return vec3(x * t, y * t, z * t); }
    __host__ __device__ float dot(const vec3 &other) const { return x * other.x + y * other.y + z * other.z; }
    __host__ __device__ vec3 cross(const vec3 &other) const
    {
        return vec3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x);
    }
    __host__ __device__ float length() const { return sqrtf(x * x + y * y + z * z); }
    __host__ __device__ vec3 normalize() const
    {
        float l = length();
        return l > 0 ? *this * (1.0f / l) : vec3();
    }
};

struct Ray
{
    vec3 origin;
    vec3 direction;

    __host__ __device__ Ray() {}
    __host__ __device__ Ray(const vec3 &o, const vec3 &d) : origin(o), direction(d) {}
    __host__ __device__ vec3 at(float t) const { return origin + direction * t; }
};

struct HitInfo
{
    bool hit;
    float t;
    vec3 point;
    vec3 normal;
    int triangle_id;

    __host__ __device__ HitInfo() : hit(false), t(FLT_MAX), triangle_id(-1) {}
};

struct Triangle
{
    vec3 v[3];
    vec3 normal;

    __host__ __device__ Triangle() {}
    __host__ __device__ Triangle(const vec3 &a, const vec3 &b, const vec3 &c)
    {
        v[0] = a;
        v[1] = b;
        v[2] = c;
        vec3 edge1 = b - a;
        vec3 edge2 = c - a;
        normal = edge1.cross(edge2).normalize();
    }
};

__host__ __device__ vec3 matrix_multiply(const float matrix[16], const vec3 &v)
{
    float x = matrix[0] * v.x + matrix[4] * v.y + matrix[8] * v.z + matrix[12];
    float y = matrix[1] * v.x + matrix[5] * v.y + matrix[9] * v.z + matrix[13];
    float z = matrix[2] * v.x + matrix[6] * v.y + matrix[10] * v.z + matrix[14];
    float w = matrix[3] * v.x + matrix[7] * v.y + matrix[11] * v.z + matrix[15];

    if (w != 0.0f)
    {
        x /= w;
        y /= w;
        z /= w;
    }

    return vec3(x, y, z);
}

// Ray-triangle intersection using Möller-Trumbore algorithm
__device__ bool ray_triangle_intersect(const Ray &ray, const Triangle &tri, float &t, vec3 &hit_point, vec3 &normal)
{
    const float EPSILON = 0.0000001f;

    vec3 edge1 = tri.v[1] - tri.v[0];
    vec3 edge2 = tri.v[2] - tri.v[0];
    vec3 h = ray.direction.cross(edge2);
    float a = edge1.dot(h);

    if (a > -EPSILON && a < EPSILON)
        return false; // ray is parallel to triangle

    float f = 1.0f / a;
    vec3 s = ray.origin - tri.v[0];
    float u = f * s.dot(h);

    if (u < 0.0f || u > 1.0f)
        return false;

    vec3 q = s.cross(edge1);
    float v = f * ray.direction.dot(q);

    if (v < 0.0f || u + v > 1.0f)
        return false;

    t = f * edge2.dot(q);

    if (t > EPSILON) // ray intersection
    {
        hit_point = ray.at(t);
        normal = tri.normal;
        return true;
    }

    return false; // line intersection but not ray intersection
}

// Shadow ray test
__device__ bool shadow_ray_test(const vec3 &point, const vec3 &light_dir, float light_distance,
                                const vec3 &surface_normal, const Triangle *triangles, int num_triangles)
{
    const float SHADOW_BIAS = 0.001f;
    Ray shadow_ray(point + surface_normal * SHADOW_BIAS, light_dir);

    for (int i = 0; i < num_triangles; i++)
    {
        float t;
        vec3 hit_point, normal;

        if (ray_triangle_intersect(shadow_ray, triangles[i], t, hit_point, normal))
        {
            if (t > 0.001f && t < light_distance - 0.001f) // hit before light
            {
                return true; // in shadow
            }
        }
    }
    return false; // not in shadow
}