#!/usr/bin/bash
SCREENSHOTS_DIR="$HOME/screenshots"
SCREENSHOT_NAME_FORMAT="screenshot-%Y.%m.%d.%H.%M.%S"
if [[ "$1" == "area" ]] || [[ "$1" == "active" ]] || [[ "$1" == "monitor" ]] || [[ "$1" == "desktop" ]]; then
	if ! pidof -s slurp; then
		GEOM=""
		pickerproc=""
		movedcursor=n
		# some of this code comes from https://github.com/hyprwm/contrib/blob/main/grimblast/grimblast
		case "$1" in
			area)
				C="$(hyprctl cursorpos)"
				C="${C/,/}"
				movedcursor=y
				hyprpicker -r -z & pickerproc="$!"
				sleep 0.1
				if ! ps -p "$pickerproc" > /dev/null; then echo "hyprpicker failed to start"; exit 1; fi
				GEOM="$({
					hyprctl clients -j | jq -r --argjson w "$(hyprctl monitors -j | jq 'map(.activeWorkspace.id)')" 'map(select([.workspace.id] | inside($w)))' | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
					hyprctl monitors -j | jq -r '.[] | "\(.x),\(.y) \(.width)x\(.height)"'
				} | slurp)"
				echo "$WINDOWS"
				;;
			active)
				GEOM="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
				;;
			monitor)
				GEOM="$(hyprctl monitors -j | jq '.[] | select(.focused == true)' | jq -r '"\(.x),\(.y) \(.width)x\(.height)"')"
				;;
		esac
		ARGS=()
		[[ -n "$GEOM" ]] && ARGS=( -g "$GEOM" )
		mkdir -p -- "$SCREENSHOTS_DIR"
		file="$SCREENSHOTS_DIR/$(date -- +"$SCREENSHOT_NAME_FORMAT").png"
		[[ "$movedcursor" == "y" ]] && hyprctl dispatch movecursor $(hyprctl monitors -j | jq -r 'map({ x: (.x + .width), y: (.y + .height) }) | [ ((map(.x) | max) - 1), ((map(.y) | max) - 1) ][]')
		grim -c "${ARGS[@]}" "$file"
		wl-copy --type image/png < "$file" || xclip -selection clipboard -target "image/png" -i < "$file"
		[[ -n "$pickerproc" ]] && kill -- "$pickerproc"
		[[ "$movedcursor" == "y" ]] && hyprctl dispatch movecursor "$C"
		notify-send -i "$file" -- "Saved screenshot" "$file"
		exit "$?"
	else
		echo "slurp or hyprpicker is already running, not taking a screenshot"
	fi
elif [[ "$1" == "color" ]] || [[ "$1" == "colour" ]]; then
	if ! pidof -s hyprpicker; then
		hex="$(hyprpicker)"
		if [[ -n "$hex" ]]; then
			magick convert -size 256x256 "xc:$hex" png:- > /tmp/color
			rgb="rgb($((0x${hex:1:2})), $((0x${hex:3:2})), $((0x${hex:5:2})))"
			echo "$hex"
			echo "$rgb"
			echo -n "$hex" | wl-copy
			notify-send -t 0 -i /tmp/color -- "$hex" "$rgb"
			exit "$?"
		fi
	else
		echo "hyprpicker is already running, not taking a screenshot"
	fi
elif [[ "$1" == "check" ]]; then
	if ! type pidof;       then echo "pidof not found";       exit 1; fi
	if ! type kill;        then echo "kill not found";        exit 1; fi
	if ! type mkdir;       then echo "mkdir not found";       exit 1; fi
	if ! type grim;        then echo "grim not found";        exit 1; fi
	if ! type tee;         then echo "tee not found";         exit 1; fi
	if ! type slurp;       then echo "slurp not found";       exit 1; fi
	if ! type wl-copy;     then echo "wl-copy not found";     fi
	if ! type xclip;       then echo "xclip not found";       fi
	if ! type wl-copy && ! type xclip; then
		echo "both wl-copy and xclip not found"; exit 1; fi
	if ! type notify-send; then echo "notify-send not found"; exit 1; fi
	if ! type hyprctl;     then echo "hyprctl not found";     exit 1; fi
	if ! type hyprpicker;  then echo "hyprpicker not found";  exit 1; fi
	if ! type magick;      then echo "magick not found";      exit 1; fi
	if ! type jq;          then echo "jq not found";          exit 1; fi
	echo "all installed!"
	exit 0
else
	echo "Usage: screenshot (area|active|monitor|desktop|color|check)"
	echo "area: Select an area"
	echo "active: Active window"
	echo "monitor: Current monitor"
	echo "desktop: All monitors"
	echo "color: Color picker"
	echo "check: Check dependencies are installed"
fi
exit 1
