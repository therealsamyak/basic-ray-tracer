#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <chrono>

#include <SDL.h>

#include "geometry.cu"
#include "kernels.cu"
#include "utils.cu"
#include "obj_loader.cu"
#include "camera.cu"
#include "renderer.cu"

using namespace std;

int main(int argc, char *argv[])
{

    string filename = "Tree.obj";
    if (argc > 1)
    {
        filename = argv[1];
    }

    // start the SDL process
    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        cerr << "SDL could not initialize! SDL_Error: " << SDL_GetError() << endl;
        return -1;
    }

    const int SCREEN_WIDTH = 800;
    const int SCREEN_HEIGHT = 600;
    const float ROTATE_STEP = 0.05f;

    // create window variable as a instance to keep track of SDL process
    SDL_Window *window = SDL_CreateWindow("CUDA Ray Tracer",
                                          SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                          SCREEN_WIDTH, SCREEN_HEIGHT, SDL_WINDOW_SHOWN);
    if (window == nullptr)
    {
        cerr << "Window could not be created! SDL_Error: " << SDL_GetError() << endl;
        SDL_Quit();
        return -1;
    }

    // create renderer
    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (renderer == nullptr)
    {
        cerr << "Renderer could not be created! SDL_Error: " << SDL_GetError() << endl;
        SDL_DestroyWindow(window);
        SDL_Quit();
        return -1;
    }

    // create texture for pixel buffer
    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                             SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);
    if (texture == nullptr)
    {
        cerr << "Texture could not be created! SDL_Error: " << SDL_GetError() << endl;
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return -1;
    }

    // initialize CUDA kernel
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    cout << "Using GPU: " << prop.name << endl;

    // try to load the .obj file, let user know if it doesn't load by catching exception
    try
    {
        load_obj(filename);
    }
    catch (const exception &e)
    {
        cerr << "Error loading OBJ file: " << e.what() << endl;
        cleanup_gpu_memory();
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return -1;
    }

    // pixel buffer
    vector<uint32_t> pixels(SCREEN_WIDTH * SCREEN_HEIGHT);

    // event loop
    bool quit = false;
    SDL_Event e;

    cout << "Controls:\n";
    cout << "  Arrow keys: Rotate model\n";
    cout << "  W/S: Zoom Out/In\n";
    cout << "  ESC: Exit\n";
    cout << "Current mode: " << "Ray-Tracing" << endl;

    auto last_time = chrono::high_resolution_clock::now();
    int frame_count = 0;

    while (!quit)
    {
        // state Machine for the event of the sdl window.
        while (SDL_PollEvent(&e) != 0)
        {
            if (e.type == SDL_QUIT) // different states
            {
                quit = true;
            }
            else if (e.type == SDL_KEYDOWN)
            {
                switch (e.key.keysym.sym)
                {
                case SDLK_ESCAPE:
                    quit = true;
                    break;
                case SDLK_LEFT:
                    rotation_y -= ROTATE_STEP;
                    break;
                case SDLK_RIGHT:
                    rotation_y += ROTATE_STEP;
                    break;
                case SDLK_UP:
                    rotation_x -= ROTATE_STEP;
                    break;
                case SDLK_DOWN:
                    rotation_x += ROTATE_STEP;
                    break;
                case SDLK_w:
                    zoom = min(3.0f, zoom + 0.1f);
                    break;
                case SDLK_s:
                    zoom = max(0.1f, zoom - 0.1f);
                    break;
                }

                rotation_x = max(-1.5f, min(1.5f, rotation_x));
            }
        }

        // render
        auto render_start = chrono::high_resolution_clock::now();

        render_ray_traced(pixels, SCREEN_WIDTH, SCREEN_HEIGHT);

        auto render_end = chrono::high_resolution_clock::now();

        // update texture
        void *texture_pixels;
        int pitch;
        if (SDL_LockTexture(texture, nullptr, &texture_pixels, &pitch) == 0)
        {
            memcpy(texture_pixels, pixels.data(), pixels.size() * sizeof(uint32_t));
            SDL_UnlockTexture(texture);
        }

        // clear and render
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);

        // calculate and display FPS
        frame_count++;
        auto current_time = chrono::high_resolution_clock::now();
        auto duration = chrono::duration_cast<chrono::milliseconds>(current_time - last_time);

        if (duration.count() >= 10000) // Every 10 seconds
        {
            auto render_time = chrono::duration_cast<chrono::microseconds>(render_end - render_start);
            double fps = frame_count * 1000.0 / duration.count();
            cout << "FPS: " << fps << " | Render time: " << render_time.count() / 1000.0 << "ms | Mode: "
                 << "Ray-Tracing" << endl;

            frame_count = 0;
            last_time = current_time;
        }
    }

    // cleanup
    cleanup_gpu_memory();
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}