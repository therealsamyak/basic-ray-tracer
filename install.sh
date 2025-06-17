# SDL
git submodule init
git submodule update --recursive --remote

if [ ! -f SDL/local/bin/sdl2-config ]; then
    rm -rf SDL
    git submodule update --recursive --remote
    cd SDL
    ./autogen.sh
    ./configure --prefix=$(pwd)/local
    make -j$(nproc)
    make install
    cd ..
    echo "SDL built successfully!"
else
    echo "SDL already built; skipping SDL build steps."
fi

export PATH=/opt/nvidia/hpc_sdk/…/bin/:$PATH

# uncomment/change this as necessary; read README for more information
# export DISPLAY=localhost:11

echo "Setup finished!"