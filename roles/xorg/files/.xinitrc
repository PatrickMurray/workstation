if [ -f ~/.Xresources ]; then
	xrdb -merge -I $HOME ~/.Xresources
fi


xrandr | grep "DP-2" | grep " connected "

if [ $? -eq 0 ];
then
	xrandr                \
	  --output  "LVDS-1"  \
	  --off

	xrandr              \
	  --output  "DP-2"  \
	  --primary         \
	  --auto

	xrandr               \
	  --output  "VGA-1"  \
	  --rotate  "left"   \
	  --left-of "DP-2"   \
	  --auto
else
	xrandr                \
	  --output  "LVDS-1"  \
	  --primary           \
	  --auto

	xrandr              \
	  --output  "DP-2"  \
	  --off

	xrandr               \
	  --output  "VGA-1"  \
	  --off
fi

xset -b

xsetroot                   \
  -solid        "#222d82"  \
  -cursor_name  left_ptr


unclutter &


exec i3

