if [ -f ~/.Xresources ]; then
	xrdb -merge -I $HOME ~/.Xresources
fi

xsetroot -solid "#222d82" -cursor_name left_ptr

exec i3

