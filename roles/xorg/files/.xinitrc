if [ -f ~/.Xresources ]; then
	xrdb -merge -I $HOME ~/.Xresources
fi

xset -b
xsetroot -solid "#222d82" -cursor_name left_ptr

unclutter &

exec i3

