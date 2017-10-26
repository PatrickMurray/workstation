if [ -f ~/.Xresources ]; then
	xrdb -merge -I $HOME ~/.Xresources
fi

exec feh --bg-fill /home/patrick/Pictures/wallpaper.jpg &
exec i3

