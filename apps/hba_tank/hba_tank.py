#!/usr/bin/env python
import socket
import sys
import math
from string import upper

''' Drive the HBRC FPGA Bot around & Demonstrate its Virtual Peripherals...

    - Opens several sockets to the HBA Daemon.
    - Listens for input events from a Gamepad.
    - Calculates Velocity and Rotation from those inputs.
    - Calculates Motor Power and Direction from the Velocity and Rotation values.
    - Updates the LEDs.
    - Updates the Motors.

    The application uses a blocking Event read loop for Gamepad input.

    Use a sceen size of at least 100x40 for best results.  Enjoy.  AGM - 8/2019
'''

# HBA Daemon settings...
HOSTNAME = 'localhost'
HOSTPORT = 8870

# Gamepad settings...
GAMEPAD_DEVICE = '/dev/input/js0'

TRIGGER_MAX    = 32767 # From Gamepad.
JOYSTICK_MAX   = 32767 # From Gamepad.
VELOCITY_MAX   = 100   # For display..
ROTATION_MAX   = 100   # For display.
MOTOR_MAX      = 40    # To motor PWM.

STEERING_SENSITIVITY = 2 # Higher values are less twitchy.

#  010000 : Left horizontal joystick
#  020000 : Left vertical joystick
#  040000 : Left trigger
#  080000 : Right horizontal joystick
#  100000 : Right vertical joystick
#  200000 : Right trigger
#  400000 : Horizontal hat switch
#  800000 : Vertical hat switch
#
# Gamepad Axis...
GAMEPAD_LEFT_STICK    = 0x030000
GAMEPAD_LEFT_TRIGGER  = 0x040000
GAMEPAD_RIGHT_STICK   = 0x180000
GAMEPAD_RIGHT_TRIGGER = 0x200000
GAMEPAD_HAT_SWITCH    = 0xc00000

#  000001 : 'A' button
#  000002 : 'B' button
#  000004 : 'X' button
#  000008 : 'Y' button
#  000010 : Left top button
#  000020 : Right top button
#  000040 : Left center button
#  000080 : Right center button
#  000100 : Top center button
#
# Gamepad Buttons...
GAMEPAD_DOWN  = 0x0001
GAMEPAD_RIGHT = 0x0002
GAMEPAD_LEFT  = 0x0004
GAMEPAD_UP    = 0x0008
GAMEPAD_TL    = 0x0010
GAMEPAD_TR    = 0x0020
GAMEPAD_BACK  = 0x0040
GAMEPAD_START = 0x0080
GAMEPAD_HOME  = 0x0100

GAMEPAD_FILTER = 0xFFFFFF & ~( 0x0
  | GAMEPAD_LEFT_STICK
  | GAMEPAD_LEFT_TRIGGER
  | GAMEPAD_RIGHT_STICK
  | GAMEPAD_RIGHT_TRIGGER
  | GAMEPAD_HAT_SWITCH
  | GAMEPAD_DOWN
  | GAMEPAD_RIGHT
  | GAMEPAD_LEFT
  | GAMEPAD_UP
  | GAMEPAD_TL
  | GAMEPAD_TR
  | GAMEPAD_HOME
)

# LED patterns...
LEDS_FRONT = 0b00111100
LEDS_LEFT  = 0b11000000
LEDS_RIGHT = 0b00000011

# Send an HBA Set command to the FPGA and wait for an acknowledgement...
def hba_set( sock, set_str ):
    sock.send(set_str)
    hba_set.reply = ''

    while True:
        char = sock.recv(1)

        if char == '\\':
            break

        hba_set.reply = hba_set.reply + char

        sys.stderr.write(char)

    sys.stderr.flush()

    return hba_set.reply

# Convert an integer into a Binary encoded String 8 characters long...
def bin8(i):

    if i < 0b10000000:
        i |= 0b100000000
        i &= 0b111111111

    return bin(i)[-8:]

# Convert an integer into a Hex encoded String 4 characters long...
def hex4(i):

    if i < 0x1000:
        i |= 0x10000
        i &= 0x1ffff

    return hex(i)[-4:]

# Display Text with ANSI codes for inverse color...
def inverse(text):
    return "\033[7m" + text  + "\033[0m"

# Display the Tank's Dashboard...
def print_dashboard( 
    lights, 
    velocity, rotation,
    motor_speed_l, motor_speed_r, mode,
    trigger_reverse_l, trigger_reverse_r,
):

    sys.stdout.write(
        DASHBOARD_FORM % (
            bin8(lights),
            velocity,
            rotation,
            inverse('REVERSE') if trigger_reverse_l else '',
            inverse('REVERSE') if trigger_reverse_r else '',
            motor_speed_l,
            upper(mode),
            motor_speed_r,
       )
    )
    sys.stdout.write("\033[37;1H")
    sys.stdout.flush()

# ANSI - Cursor to Top of Screen...
DASHBOARD_FORM = '''\033[1;1H
     ________________________________________________
    |                                                |
    |                    LIGHTS                      |
    |                  [ %s ]                  |
    |------------------------------------------------|
    |                Velocity: %-8i              |
    |                Rotation: %-8i              |
    |------------------------------------------------|
    |  Motor: %7s  |   MODE   |  Motor: %7s  |
    |        %-8i  |  [ %s ]  |        %-8i  |
    |________________________________________________|
'''

# Display the Gamepad inputs...
def print_gamepad(state):
    buttons = int( state[1], 16 )
    axis    = map( int, state[2:] )

    sys.stdout.write(
        GAMEPAD_FORM % (
            hex4(axis[2]), hex4(axis[5]),
            inverse('TL') if buttons & GAMEPAD_TL    else 'tl',
            inverse('TR') if buttons & GAMEPAD_TR    else 'tr',

            inverse('Y')  if buttons & GAMEPAD_UP    else 'y',
            hex4(axis[6]),
            inverse('HO') if buttons & GAMEPAD_HOME  else 'ho',
            inverse('X')  if buttons & GAMEPAD_LEFT  else 'x',
            inverse('B')  if buttons & GAMEPAD_RIGHT else 'b',
            hex4(axis[7]),
            inverse('A')  if buttons & GAMEPAD_DOWN  else 'a',

            hex4(axis[0]), hex4(axis[3]),
            hex4(axis[1]), hex4(axis[4]),
        )
    )
    sys.stdout.write("\033[37;1H")
    sys.stdout.flush()

# ANSI - Cursor to Line;Col...
GAMEPAD_FORM = '''\033[14;1H
             ___________           ___________            __
            / [ %04s ]  \_________/  [ %04s ] \             | Front
           /    [%s]                   [%s]    \            | Triggers
        __/_____________________________________\__       __|
       /                                           \        |
      /     /\        |SE|      |ST|        (%s)     \       |
     /  x [%04s]           |%s|                      \      | Main Pad
    |   <===DP===>                      (%s) -|- (%s)   |     |
     \  y [%04s]    ____           ____              /    __|
     /\     \/     /    \ R   x/y /    \    (%s)     /\      |
    /  \          [ %04s ]       [ %04s ]          /  \     | Control
    |   \________ [ %04s ] _____ [ %04s ] ________/   |     | Sticks
    |        /   \ \____/ /     \ \____/ /   \        |   __| 
    |       /     \______/       \______/     \       |
    |      /                                   \      |
    \_____/                                     \_____/

        \________\______\_______/______/_________/
          D-Pad   Left    Menu    Right   Action
                  Stick    Pad    Stick    Pad
'''

# Place Error/Debug messages at explicit screen locations...
def print_debug(*text):

    # ANSI - Cursor to Line;Col...
    sys.stdout.write( "\033[35;1H" )
    sys.stdout.write( " ".join( map( str, text ) ) )
    sys.stdout.write( "\033[K\033[37;1H" )

def print_warning(*text):

    # ANSI - Cursor to Line;Col...
    sys.stdout.write( "\033[36;1H" )
    sys.stdout.write( " ".join( map( str, text ) ) )
    sys.stdout.write( "\033[K\033[37;1H" )

# Calculate LED values from a Button value...
def buttons_to_leds( buttons, leds ):

    if buttons & GAMEPAD_UP:
        leds ^= LEDS_FRONT

    if buttons & GAMEPAD_LEFT:
        leds &= ~LEDS_RIGHT
        leds ^=  LEDS_LEFT

    if buttons & GAMEPAD_RIGHT:
        leds &= ~LEDS_LEFT
        leds ^=  LEDS_RIGHT

    if buttons & GAMEPAD_DOWN:
        leds = 0

    return leds

# Map Trigger values with their Reverse buttons...
def map_trigger_values( trigger, reverse ):
    trigger = ( trigger + TRIGGER_MAX + 1 ) / 2

    if reverse:
        trigger = -trigger

    return trigger

# Calculate Vectors from Trigger position values...
def triggers_to_rotation_velocity( trigger_l, trigger_r ):
    rotation = ( trigger_l - trigger_r ) * ROTATION_MAX / TRIGGER_MAX / 2
    velocity = ( trigger_l + trigger_r ) * VELOCITY_MAX / TRIGGER_MAX / 2

    return ( round(rotation), round(velocity) )

# Calculate Vectors from Joystick position values...
def joystick1_to_rotation_velocity( joystick_x, joystick_y ):
    rotation = joystick_x * ROTATION_MAX / JOYSTICK_MAX
    velocity = joystick_y * VELOCITY_MAX / JOYSTICK_MAX

    rotation = ROTATION_MAX if rotation > ROTATION_MAX \
        else -ROTATION_MAX if rotation < -ROTATION_MAX \
        else rotation

    velocity = VELOCITY_MAX if velocity > VELOCITY_MAX \
        else -VELOCITY_MAX if velocity < -VELOCITY_MAX \
        else velocity

    return ( round(rotation), round(-velocity) )

# Calculate Rotate vector from X Joystick position value...
def joystick2_to_rotation_velocity( joystick_x, joystick_y ):
    rotation = joystick_x * ROTATION_MAX / JOYSTICK_MAX
    velocity = 0

    return ( round(rotation), round(velocity) )

# Calculate mapped Motor values from Velocity and Rotation vectors...
def velocity_rotation_to_motor_speeds( velocity, rotation ):
    motor_power_l = ( velocity * MOTOR_MAX / VELOCITY_MAX \
      + rotation * MOTOR_MAX / ROTATION_MAX / STEERING_SENSITIVITY )

    motor_power_r = ( velocity * MOTOR_MAX / VELOCITY_MAX \
      - rotation * MOTOR_MAX / ROTATION_MAX / STEERING_SENSITIVITY )

    motor_power_l = MOTOR_MAX if motor_power_l > MOTOR_MAX \
        else -MOTOR_MAX if motor_power_l < -MOTOR_MAX \
        else motor_power_l

    motor_power_r = MOTOR_MAX if motor_power_r > MOTOR_MAX \
        else -MOTOR_MAX if motor_power_r < -MOTOR_MAX \
        else motor_power_r

    return ( round(motor_power_l), round(motor_power_r) )

# Set motor Reverse Mode for negative Motor Power values...
def motor_to_mode( motor_power, mode ):
    return 'r' if motor_power < 0 else 'f' if motor_power > 0 else mode

#
# Main
#
try:
    # Open connections to HBA daemon...
    sock_gamepad = socket.socket( socket.AF_INET, socket.SOCK_STREAM )
    sock_motor   = socket.socket( socket.AF_INET, socket.SOCK_STREAM )
    sock_basicio = socket.socket( socket.AF_INET, socket.SOCK_STREAM )

    sock_gamepad.connect(( HOSTNAME, HOSTPORT ))
    sock_motor.connect(( HOSTNAME, HOSTPORT ))
    sock_basicio.connect(( HOSTNAME, HOSTPORT ))

    print "Connected."

    # Initialize all LEDs to Off..
    hba_set( sock_basicio, 'hbaset hba_basicio leds 0\n' )

    leds    = old_leds    = 0
    buttons = old_buttons = 0

    # Initialize Motors to Forward and Stopped...
    hba_set( sock_motor, 'hbaset hba_motor mode cc\n' )
    hba_set( sock_motor, 'hbaset hba_motor motor0 0\n' )
    hba_set( sock_motor, 'hbaset hba_motor motor1 0\n' )
    hba_set( sock_motor, 'hbaset hba_motor mode ff\n' )

    motor_speed_l = old_motor_speed_l = 0
    motor_speed_r = old_motor_speed_r = 0
    motor_mode    = old_motor_mode    = 'ff'

    trigger_reverse_l = False
    trigger_reverse_r = False

    # Initialize Gamepad device Path and Event timing...
    hba_set( sock_gamepad, 'hbaset gamepad period 0\n' )
    hba_set( sock_gamepad, 'hbaset gamepad filter %6x\n' % GAMEPAD_FILTER )
    hba_set( sock_gamepad, 'hbaset gamepad device %s\n'  % GAMEPAD_DEVICE )

    # Reset Dashboard values...
    rotation = 0
    velocity = 0

    # Start events from Gamepad.
    sock_gamepad.send('hbacat gamepad state\n')

    print "Running..."

    # ANSI - Clear Screen...
    print "\033[2J"

    # Display Dashboard and Gamepad...
    print_dashboard(
        leds,
        velocity, rotation,
        motor_speed_l, motor_speed_r, motor_mode,
        trigger_reverse_l, trigger_reverse_r,
    )

    print_gamepad(
        ( 0, '0', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ),
    )

    # Loop forever reading Input and displaying the Dashboard...
    while True:
        gamepad_state = sock_gamepad.recv(1024).split()

        if len(gamepad_state) < 10:
            print_warning(
                "WARNING: Bad data from HBA Daemon:",
                "Length:", len(gamepad_state),
            )
            continue

        # Display Gamepad...
        print_gamepad(gamepad_state)

        # Ignore any buttons that were already pressed...
        buttons     = int( gamepad_state[1], 16 ) & ~ old_buttons
        old_buttons = int( gamepad_state[1], 16 )

        # Get joystick axis values...
        axis = map( int, gamepad_state[2:] )

        left_joystick_x = axis[0]
        left_joystick_y = axis[1]

        trigger_l  = axis[2]

        right_joystick_x = axis[3]
        right_joystick_y = axis[4]

        trigger_r = axis[5]

        hat_switch_x = axis[6] # Unused.
        hat_switch_y = axis[7] # Unused.

        # Toggle the Trigger Reverse flags if Button is pressed...
        if buttons & GAMEPAD_TL:
            trigger_reverse_l = ~ trigger_reverse_l

        if buttons & GAMEPAD_TR:
            trigger_reverse_r = ~ trigger_reverse_r

        # Calculate LEDs values from Buttons...
        leds = buttons_to_leds( buttons, old_leds )

        # Adjust the raw Trigger values to range of +-TRIGGER_MAX...
        trigger_l = map_trigger_values( trigger_l, trigger_reverse_l )
        trigger_r = map_trigger_values( trigger_r, trigger_reverse_r )

        # Calculate Velocity and Rotation from Gamepad inputs...
        ( rotation, velocity ) = \
            triggers_to_rotation_velocity( trigger_l, trigger_r )

        ## Use Left Stick just for Spinning...
        if velocity == 0 and rotation == 0:
            ( rotation, velocity ) = \
            joystick2_to_rotation_velocity( left_joystick_x, left_joystick_y )

        ## Use Right Stick for Full Control...
        if velocity == 0 and rotation == 0:
            ( rotation, velocity ) = \
            joystick1_to_rotation_velocity( right_joystick_x, right_joystick_y )

        # Calculate Motor Speeds from Velocity and Rotation values...
        ( motor_speed_l, motor_speed_r ) = velocity_rotation_to_motor_speeds( velocity, rotation )

        # Calculate motor Mode setting for negative Motor Speeds...
        motor_mode_l = motor_to_mode( motor_speed_l, old_motor_mode[0:1] )
        motor_mode_r = motor_to_mode( motor_speed_r, old_motor_mode[1:2] )
        motor_mode   = motor_mode_l + motor_mode_r

        # Display updated Dashboard...
        print_dashboard(
            leds, velocity, rotation,
            motor_speed_l, motor_speed_r, motor_mode,
            trigger_reverse_l, trigger_reverse_r,
        )

        # Update LEDs...
        if leds != old_leds:
            hba_set( sock_basicio, 'hbaset hba_basicio leds %x\n' % leds )
            old_leds = leds

        # Put Transmision in Neutral while we Shift into/out of Reverse...
        if motor_mode != old_motor_mode:
            hba_set( sock_motor, 'hbaset hba_motor mode cc\n' )
            old_motor_mode = 'cc'

        # Update Motor Speeds...
        if motor_speed_l != old_motor_speed_l:
            hba_set( sock_motor, 'hbaset hba_motor motor0 %i\n' % abs(motor_speed_l) )
            old_motor_speed_l = motor_speed_l

        if motor_speed_r != old_motor_speed_r:
            hba_set( sock_motor, 'hbaset hba_motor motor1 %i\n' % abs(motor_speed_r) )
            old_motor_speed_r = motor_speed_r

        # Update Motor direction Mode...
        if motor_mode != old_motor_mode:
            hba_set( sock_motor, 'hbaset hba_motor mode %s\n' % motor_mode )
            old_motor_mode = motor_mode

        # Exit?...
        if buttons & GAMEPAD_HOME:
            raise KeyboardInterrupt

except KeyboardInterrupt:

    print "Stopping..."

    # Disable Motors...
    hba_set( sock_motor, 'hbaset hba_motor mode cc\n' )
    hba_set( sock_motor, 'hbaset hba_motor motor0 0\n' )
    hba_set( sock_motor, 'hbaset hba_motor motor1 0\n' )

    # Disable Leds...
    hba_set( sock_basicio, 'hbaset hba_basicio leds 0\n' )

    # exit on Ctrl^C
    sock_motor.close()
    sock_basicio.close()
    sock_gamepad.close()

    print 'Parked.'
    sys.exit()

except socket.error:
    print "Couldn't connect to HBA Daemon!"
    sys.exit()

