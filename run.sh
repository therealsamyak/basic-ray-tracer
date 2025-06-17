# compile + run (for now)

echo "Compiling code..."

nvc++ -std=c++11 -mp=gpu -target=gpu     -I./include     $(./SDL/local/bin/sdl2-config --cflags)     src/main.cu     -o ray_tracer     $(./SDL/local/bin/sdl2-config --libs)

if [ -f ./ray_tracer ]; then
    echo "Compilation successful! Executing code..."
    ./ray_tracer
    rm -f ray_tracer
else
    echo "Compilation Error! Try again later..."
fi
