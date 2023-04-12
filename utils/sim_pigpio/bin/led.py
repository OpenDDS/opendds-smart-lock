# ******************************************************************
#      Author: Chad Elliott
#        Date: 4/11/2023
# Description: Simulate a pair of LEDs that will can be controlled
#              via the simulated pigpio library.
# ******************************************************************

# ******************************************************************
# Import Section
# ******************************************************************

import socket, sys, argparse

# ******************************************************************
# Data Section
# ******************************************************************

x = 0

# ******************************************************************
# Function Section
# ******************************************************************

def incx():
    '''Increment the global "x" variable and return it's value.  This
function allows us to increment "x" and use it's value at the same time.'''
    global x
    x += 1
    return x

def clrscr():
    '''Use the VT100 code to clear the screen.'''
    print("\033[2J", end="")
    sys.stdout.flush()

def drawLED(index, value):
    '''Draw an old-school shaded LED using VT100 codes.
index - 0 or 1 to indicate which LED
value - 0 or 1 to indicate low or high
'''
    if (index < 0 or index > 2):
        return

    global x
    color = (31 + index) if (value) else 37
    y = (index * 40) + 2
    x = 1
    print("\033[{}m".format(color), end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("            ▒▒▒▒▒▒▒▒▒▒▒▒▒▒            ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("        ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒        ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒      ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒    ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("  ▒▒▒▒▒▒▒███▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("  ▒▒▒▒▒███████▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("▒▒▒▒▒▒▒███████▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("▒▒▒▒▒▒▒▒▒███▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒    ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒      ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("        ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒        ", end="")
    print("\033[{};{}H".format(incx(), y), end="")
    print("            ▒▒▒▒▒▒▒▒▒▒▒▒▒▒            ", end="")
    print("\033[m\033[24;1H", end="")
    sys.stdout.flush()

def server_program(port):
    '''Listen for connections from the simulated pigpio library.  Update the
visual state of the LEDs with data received.  Only one connection is
allowed at a time.'''
    ## Prepare the screen for output
    clrscr()
    sys.stdout.reconfigure(encoding='utf-8')

    ## Show the initial information and state
    print("\033[22;1H", end="")
    print("Press Control-Break to quit.", end="")
    sys.stdout.flush()
    drawLED(0, 0)
    drawLED(1, 0)

    ## Listen for connections
    s = socket.socket()
    s.bind(('localhost', port))
    s.listen(1)
    expected = 2
    while(True):
        conn, address = s.accept()
        while(True):
            try:
                data = conn.recv(expected)
            except:
                data = None

            if (data is not None and len(data) == expected):
                drawLED(data[0] - 10, data[1])
            else:
                break
    conn.close()

# ******************************************************************
# Main Section
# ******************************************************************

if __name__ == '__main__':
    ## Parse command line arguments
    parser = argparse.ArgumentParser(
               formatter_class=argparse.ArgumentDefaultsHelpFormatter,
               description='Provides an LED simulator.')
    parser.add_argument('--port', help='The port on which to listen.',
                        type=int, default=4746)
    args = parser.parse_args()
    if (args.port < 0 or args.port > 65535):
        print("The port must be between 0-65535.")
    else:
        ## Run the server
        server_program(args.port)
