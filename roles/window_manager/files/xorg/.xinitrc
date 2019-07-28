#!/bin/dash


# Read a custom X resource profile if it exists
if [ -f ~/.Xresources ];
then
	xrdb        \
	  -merge    \
	  -I $HOME  \
	  ~/.Xresources;
fi


# Disable the system's bell to save headphone users
xset -b off


# Set the background color for each display
xsetroot                   \
  -solid        "#222d82"  \
  -cursor_name  "left_ptr";


# Remove an idle cursor from the display, useful when using a primarily
# keyboard heavy workflow
#unclutter &


# Start up the window manager
exec i3
