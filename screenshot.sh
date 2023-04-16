#!/usr/bin/bash
SCREENSHOTS_DIR="$HOME/screenshots"
SCREENSHOT_NAME_FORMAT="screenshot-%Y.%m.%d.%H.%M.%S"
if [[ "$1" == "area" ]] || [[ "$1" == "active" ]] || [[ "$1" == "screen" ]] || [[ "$1" == "output" ]] || [[ "$1" == "color" ]]; then
	if ! pidof slurp hyprpicker; then
		if [[ "$1" == "color" ]]; then
			hex="$(hyprpicker)"
			if [[ -n "$hex" ]]; then
				magick convert -size 256x256 "xc:$hex" png:- > /tmp/color
				r="$((0x${hex:1:2}))"
				g="$((0x${hex:3:2}))"
				b="$((0x${hex:5:2}))"
				echo -n "$hex" | wl-copy
				notify-send -t 0 -i /tmp/color -- "$hex" "rgb($r, $g, $b)"
			fi
		else
			hyprpicker -r -z & pickerproc="$!"
			mkdir -p -- "$SCREENSHOTS_DIR"
			file="$SCREENSHOTS_DIR/$(date -- +"$SCREENSHOT_NAME_FORMAT").png"
			grimblast save area - | tee "$file" | wl-copy --type image/png
			kill -- "$pickerproc"
			notify-send -i "$file" -- "Saved screenshot" "$file"
			exit $?
		fi
	fi
else
	echo "Usage: screenshot (area|active|screen|color)"
fi
exit 1
