#pragma once

#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <cfloat>

#define TINYOBJLOADER_IMPLEMENTATION
#include "tiny_obj_loader.h"

#include "geometry.cu"

using namespace std;

// global definitions for OBJ data
vector<Triangle> triangles;
vector<Triangle> original_triangles;
vec3 model_center;
float model_scale = 1.0f;

void load_obj(const string &filename)
{
    tinyobj::attrib_t attrib;
    vector<tinyobj::shape_t> shapes;
    vector<tinyobj::material_t> materials;
    string warn, err;

    bool success = tinyobj::LoadObj(&attrib, &shapes, &materials, &warn, &err, filename.c_str());
    if (!warn.empty())
        cout << "WARN: " << warn << endl;
    if (!err.empty())
        cerr << "ERR: " << err << endl;
    if (!success)
        throw runtime_error("Failed to load OBJ file.");

    cout << "Loaded OBJ: " << filename << "\n";
    cout << "Vertices: " << (attrib.vertices.size() / 3) << "\n";
    cout << "Shapes:   " << shapes.size() << "\n";

    // calculate bounding box
    vec3 min_bounds(FLT_MAX, FLT_MAX, FLT_MAX);
    vec3 max_bounds(-FLT_MAX, -FLT_MAX, -FLT_MAX);

    vector<vec3> all_vertices;
    for (size_t i = 0; i < attrib.vertices.size(); i += 3)
    {
        vec3 v(attrib.vertices[i], attrib.vertices[i + 1], attrib.vertices[i + 2]);
        all_vertices.push_back(v);

        min_bounds.x = min(min_bounds.x, v.x);
        min_bounds.y = min(min_bounds.y, v.y);
        min_bounds.z = min(min_bounds.z, v.z);

        max_bounds.x = max(max_bounds.x, v.x);
        max_bounds.y = max(max_bounds.y, v.y);
        max_bounds.z = max(max_bounds.z, v.z);
    }

    model_center = (min_bounds + max_bounds) * 0.5f;
    vec3 size = max_bounds - min_bounds;
    model_scale = 3.0f / max({size.x, size.y, size.z});

    cout << "Model bounds: (" << min_bounds.x << "," << min_bounds.y << "," << min_bounds.z << ") to ("
              << max_bounds.x << "," << max_bounds.y << "," << max_bounds.z << ")\n";
    cout << "Model center: (" << model_center.x << "," << model_center.y << "," << model_center.z << ")\n";
    cout << "Model scale: " << model_scale << "\n";

    // extract triangles from obj file
    triangles.clear();
    original_triangles.clear();
    for (const auto &shape : shapes)
    {
        for (size_t f = 0; f < shape.mesh.indices.size(); f += 3)
        {
            vec3 vertices[3];
            bool valid_triangle = true;

            for (int i = 0; i < 3; i++)
            {
                int vi = shape.mesh.indices[f + i].vertex_index;
                if (vi < 0 || vi >= (int)all_vertices.size())
                {
                    valid_triangle = false;
                    break;
                }

                vertices[i] = all_vertices[vi];
                // normalize vertex
                vertices[i] = (vertices[i] - model_center) * model_scale;
            }

            if (valid_triangle)
            {
                Triangle tri(vertices[0], vertices[1], vertices[2]);
                triangles.push_back(tri);
                original_triangles.push_back(tri);
            }
        }
    }

    cout << "Extracted " << triangles.size() << " triangles.\n";
}