# Getting Started

Set your PIGPIO_DIR environment to the full path of the `sim_pigpio` directory.

# Building

Use MPC to generate the workspace in the `$PIGPIO_DIR` directory and build for your platform as you would for any other ACE-based library.

When generating workspace for the SmartLock app, be sure to pass `-features no_pigpio=0` to MPC.

# Running

Start the LED simulator using `python $PIGPIO_DIR/bin/led.py`
Run the `smartlock` app as you normally would.  If everything was done correctly, the LED on the right should turn green.

If you are going to run more than one smartlock app, you can run multiple LED simulators providing different port numbers using the `--port` option.  Then before running the smartlock app, set the PIGPIO_PORT environment variable to the corresponding port number.

