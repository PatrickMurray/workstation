<<<<<<< HEAD
#!/bin/bash
=======
#! /usr/bin/env bash
>>>>>>> 3238b2fe0105a8e4c1430b51ec062e25730bb1ed


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
<<<<<<< HEAD
if [[ -f ~/.Xresources ]];
then
	echo "xrdb"
=======
if [ -f ~/.Xresources ];
then
>>>>>>> 3238b2fe0105a8e4c1430b51ec062e25730bb1ed
	xrdb        \
	  -merge    \
	  -I $HOME  \
	  ~/.Xresources;
fi


<<<<<<< HEAD
check_display_availability () {
	echo "checking argument"
	if [[ -z ${1} ]];
	then
		echo "check_display_availability: a display argument must be provided"
=======
function check_display_availability {
	if [[ -z ${1} ]];
	then
		logger "check_display_availability: a display argument must be provided"
>>>>>>> 3238b2fe0105a8e4c1430b51ec062e25730bb1ed
		echo false
		exit
	fi

	DISPLAY_IDENTIFIER=${1}

<<<<<<< HEAD
	echo "check_display_availability: checking ${DISPLAY_IDENTIFIER}"

	xrandr | grep ${DISPLAY_IDENTIFIER} | grep "connected"
=======
	logger "check_display_availability: checking ${DISPLAY_IDENTIFIER}"

	xrandr | grep ${DISPLAY_IDENTIFIER} | grep "connected" > /dev/null
>>>>>>> 3238b2fe0105a8e4c1430b51ec062e25730bb1ed

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
<<<<<<< HEAD
echo "defining display available"
=======
>>>>>>> 3238b2fe0105a8e4c1430b51ec062e25730bb1ed
DISPLAY_INTEGRATED_AVAILABLE=$(check_display_availability ${DISPLAY_INTEGRATED})
DISPLAY_ONE_AVAILABLE=$(check_display_availability ${DISPLAY_ONE})
DISPLAY_TWO_AVAILABLE=$(check_display_availability ${DISPLAY_TWO})


# Setup displays
if [[ ${DISPLAY_ONE_AVAILABLE} && ${DISPLAY_TWO_AVAILABLE} ]];
then
<<<<<<< HEAD
	echo "conditional 1"
=======
>>>>>>> 3238b2fe0105a8e4c1430b51ec062e25730bb1ed
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
<<<<<<< HEAD
	echo "conditional 2"
=======
>>>>>>> 3238b2fe0105a8e4c1430b51ec062e25730bb1ed
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

