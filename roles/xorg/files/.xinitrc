#! /usr/bin/env bash


# Display Setup
#
#  +--------+
#  |        |
#  |        | +----------------+
#  |        | |                |
#  |  DP-1  | |      DP-2      |    +--------+
#  |        | |                |    | LVDS-2 |
#  |        | +----------------+    +--------+
#  +--------+                        \ ###### \
#                                     +--------+
#
#   Display 1      Display 2          Integrated



# Read a custom X resource profile if it exists
if [ -f ~/.Xresources ];
then
	xrdb        \
	  -merge    \
	  -I $HOME  \
	  ~/.Xresources;
fi


function check_display_availability {
	if [[ -z ${1} ]];
	then
		logger "check_display_availability: a display argument must be provided"
		echo false
		exit
	fi

	DISPLAY_IDENTIFIER=${1}

	logger "check_display_availability: checking ${DISPLAY_IDENTIFIER}"

	xrandr | grep ${DISPLAY_IDENTIFIER} | grep "connected" > /dev/null

	if [[ $? -eq 0 ]];
	then
		echo true
		exit
	fi

	echo false
	exit
}


# Display Interfaces
DISPLAY_INTEGRATED="LVDS-2"
DISPLAY_ONE="DP-1"
DISPLAY_TWO="DP-2"


# Determine the status of each display
DISPLAY_INTEGRATED_AVAILABLE=$(check_display_availability ${DISPLAY_INTEGRATED})
DISPLAY_ONE_AVAILABLE=$(check_display_availability ${DISPLAY_ONE})
DISPLAY_TWO_AVAILABLE=$(check_display_availability ${DISPLAY_TWO})


# Setup displays
if [[ ${DISPLAY_ONE_AVAILABLE} && ${DISPLAY_TWO_AVAILABLE} ]];
then
	# Turn off the integrated display
	xrandr                            \
	  --output ${DISPLAY_INTEGRATED}  \
	  --off;

	# Turn on display one, position it to the left of display two, and
	# rotate it's output
	xrandr                      \
	  --output  ${DISPLAY_ONE}  \
	  --rotate  "left"          \
	  --left-of ${DISPLAY_TWO}  \
	  --auto;

	# Turn on display two and set it as the primary
	xrandr                     \
	  --output ${DISPLAY_TWO}  \
	  --primary                \
	  --auto;

else
	# Turn on the integrated display and set it as the primary
	xrandr                             \
	  --output  ${DISPLAY_INTEGRATED}  \
	  --primary                        \
	  --auto;

	# Turn off display one
	xrandr                     \
	  --output ${DISPLAY_ONE}  \
	  --off

	# Turn off display two
	xrandr                     \
	  --output ${DISPLAY_TWO}  \
	  --off;
fi


# Disable the system's bell to save headphone users
xset -b off


# Set the background color for each display
xsetroot                   \
  -solid        "#222d82"  \
  -cursor_name  left_ptr;


# Remove an idle cursor from the display, useful when using a primarily
# keyboard heavy workflow
unclutter &


# Start up the window manager
exec i3

