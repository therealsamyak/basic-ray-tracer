# Ray Tracing w/ Cuda

[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/5-zirqst)

## Installation

### Dependencies

- You need some type of local X11 server for port forwarding, like [VcXsrv](https://github.com/marchaesen/vcxsrv/releases/tag/21.1.16.1)
- You need to set a GLOBAL **DISPLAY** Environment Variable in Windows to localhost:\<number\> here. The actual number doesn't matter; make sure both your X11 server and your Windows GLOBAL **DISPLAY** variable use the same port.

### Instructions

#### VcXsrv / X11 Setup

1. Set the `DISPLAY` Environment Variable in Windows to `localhost:<number>`. Search "Environment Variables" on Windows Search, then go from there.
2. Download and setup VcXsrv. When launching it, make sure the port number matches the `DISPLAY` Environment Variable. Also, **DISABLE ACCESS CONTROL**.
3. Edit the SSH config to allow

  ```bash
  ForwardX11 yes
  ForwardX11Trusted yes
  ```

  for the server.

#### Bender Server

0. Connect to the ENGR Bender server (or any server with cuda-supported GPUs).

1. Open your terminal and run:

   ```bash
   xauth list
   ```

2. Look for a line that looks like this:

   ```bash
   <server>/unix:12  ...
   ```

3. There may be multiple entries. It's usually the last one or one near the bottom.

4. Note the number after `unix:` (e.g., `:12`). This is your display port.

5. Go to `[install.sh]`. Set your `DISPLAY` environment variable to match, replacing `<num>` with your port:

   ```bash
   export DISPLAY=localhost:<num>
   ```

   For example, if your port is `:12`, use:

   ```bash
   export DISPLAY=localhost:12
   ```

6. Test that the DISPLAY is working by running:

   ```bash
   xeyes
   ```

7. If you're having issues or too many entries show up, you can reset the list by running:

   ```bash
   rm -f ~/.Xauthority
   ```

   Then disconnect from the server and reconnect again. Follow the instructions from the top again.

8. Run the installation and compilation scripts

    ```bash
    # install
    source install.sh

    # compile + run (all-in-one!)
    source run.sh
    ```

### Controls

- W/S to Zoom Out/In
- Arrow keys to rotate object
- ESC to quit. You can also click the red X in the top corner of the GUI to quit as well.

## Authors

- Samyak Kakatur
- Kunal Shrivastav
- Falak Tulsi
