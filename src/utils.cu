#pragma once

#include <cuda.h>
#include <cstdio>

#include "geometry.cu"

#define CUDA_CHECK(call)                                                      \
    do                                                                        \
    {                                                                         \
        cudaError_t err = call;                                               \
        if (err != cudaSuccess)                                               \
        {                                                                     \
            fprintf(stderr, "CUDA error at %s:%d code=%d(%s) \"%s\"\n",       \
                    __FILE__, __LINE__, err, cudaGetErrorString(err), #call); \
            exit(EXIT_FAILURE);                                               \
        }                                                                     \
    } while (0)

Triangle *d_triangles = nullptr;
uint32_t *d_pixels = nullptr;
size_t current_allocated = 0;

void cleanup_gpu_memory()
{
    if (d_triangles)
    {
        CUDA_CHECK(cudaFree(d_triangles));
        d_triangles = nullptr;
    }
    if (d_pixels)
    {
        CUDA_CHECK(cudaFree(d_pixels));
        d_pixels = nullptr;
    }
}