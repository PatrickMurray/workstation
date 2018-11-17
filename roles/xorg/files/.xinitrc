#!/bin/dash


# Display Setup
#
#  +--------+
#  |        |
#  |        | +----------------+
#  |        | |                |
#  |  DP-1  | |      DP-2      |    +--------+
#  |        | |                |    | LVDS-1 |
#  |        | +----------------+    +--------+
#  +--------+                        \ ###### \
#                                     +--------+
#
#   Display 1      Display 2          Integrated
#
# TODO - Display 1 is currently inactive.
#


# Display Interfaces
DISPLAY_INTEGRATED="LVDS-1"
DISPLAY_ONE="DP-1"
DISPLAY_TWO="DP-2"


# Read a custom X resource profile if it exists
if [ -f ~/.Xresources ];
then
	xrdb        \
	  -merge    \
	  -I $HOME  \
	  ~/.Xresources;
fi


check_display_availability () {
	if [ -z $1 ];
	then
		logger --stderr "check_display_availability: a display argument must be provided"
		printf "false"
		exit
	fi
	
	DISPLAY_IDENTIFIER=${1}
	
	if xrandr | grep "${DISPLAY_IDENTIFIER} connected" >> /dev/null;
	then
		logger --stderr "check_display_availability: display ${DISPLAY_IDENTIFIER} available"
		printf "true"
		exit
	fi

	printf "false"
	exit
}


# Determine the status of each display
DISPLAY_INTEGRATED_AVAILABLE=$(check_display_availability ${DISPLAY_INTEGRATED})
DISPLAY_ONE_AVAILABLE=$(check_display_availability ${DISPLAY_ONE})
DISPLAY_TWO_AVAILABLE=$(check_display_availability ${DISPLAY_TWO})


# Setup displays
if [ "${DISPLAY_TWO_AVAILABLE}" = "true" ];
then
	xrandr                              \
	  --output "${DISPLAY_INTEGRATED}"  \
	  --off;

	xrandr                       \
	  --output "${DISPLAY_TWO}"  \
	  --primary                  \
	  --auto;
else
	xrandr                              \
	  --output "${DISPLAY_INTEGRATED}"  \
	  --primary                         \
	  --auto;

	xrandr                       \
	  --output "${DISPLAY_TWO}"  \
	  --off;
fi


# Disable the system's bell to save headphone users
xset -b off


# Set the background color for each display
xsetroot                   \
  -solid        "#222d82"  \
  -cursor_name  "left_ptr";


# Remove an idle cursor from the display, useful when using a primarily
# keyboard heavy workflow
unclutter &


# Start up the window manager
exec i3
