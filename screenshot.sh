#!/usr/bin/bash
function list-clients() {
	# prepare a list of visible windows
	# select windows that are on the same workspace as its monitor's current workspace or pinned to all workspaces
	# which are mapped and visible
	hyprctl clients -j | jq -r --argjson monitors "$(hyprctl monitors -j)" \
		'.[] | select(.monitor as $monitor_id | (.workspace.id == ($monitors[] | select(.id == $monitor_id)).activeWorkspace.id or .pinned) '"\
			"'and .mapped and (.hidden | not)) '"\
			"'| ["\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])", .address] | [.[0], .[1], .[0]] | join(" ")'
	# outputs "[x],[y] [w]x[h] [window address] [x],[y] [w]x[h]"
}
function list-monitors() {
	# prepare a list of monitors, with swapped width and height for portrait monitors
	hyprctl monitors -j | jq -r '. | map(if .transform % 2 == 1 then . + {width: .height, height: .width} else . end) | .[] | "\(.x),\(.y) \(.width)x\(.height)"'
}
function screenshot() {
	local SCREENSHOTS_DIR SCREENSHOT_NAME_FORMAT PICKER_PROC GEOM GEOM_POS GEOM_SIZE GEOM_WIN GEOM_EXTRA
	SCREENSHOTS_DIR="$HOME/screenshots"
	SCREENSHOT_NAME_FORMAT="screenshot-%Y.%m.%d.%H.%M.%S"
	if [[ "$1" == "area" ]] || [[ "$1" == "active" ]] || [[ "$1" == "monitor" ]] || [[ "$1" == "desktop" ]]; then
		if ! pidof -s slurp; then
			# some of this code comes from https://github.com/hyprwm/contrib/blob/main/grimblast/grimblast
			case "$1" in
			area)
				hyprpicker -r -z &
				PICKER_PROC="$!"
				sleep 0.1
				GEOM="$({
					list-clients
					list-monitors
				} | slurp -f "%x,%y %wx%h %l")"
				# will output "[x],[y] [w]x[h] [window address] [wx],[wy] [ww]x[wh]"
				# where "[wx],[wy] [ww]x[wh]" matches "[x],[y] [w]x[h]" if the window is selected
				if [[ -z "$GEOM" ]]; then
					[[ -n "$PICKER_PROC" ]] && kill -- "$PICKER_PROC"
					return 1
				fi
				;;
			active)
				# outputs "[x],[y] [w]x[h] [window address] active"
				GEOM="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \(.address) active"')"
				;;
			monitor)
				# outputs "[x],[y] [w]x[h]"
				# acts the same as area
				GEOM="$(hyprctl monitors -j | jq '.[] | select(.focused == true)' | jq -r '"\(.x),\(.y) \(.width)x\(.height)"')"
				;;
			esac
			if ! ps -p "$PICKER_PROC" >/dev/null; then
				echo "hyprpicker failed to start"
				PICKER_PROC=
			fi
			ARGS=()
			if [[ -n "$GEOM" ]]; then
				IFS=' ' read -r GEOM_POS GEOM_SIZE GEOM_WIN GEOM_EXTRA <<<"$GEOM"
				GEOM="$GEOM_POS $GEOM_SIZE"
				if [[ "$GEOM_EXTRA" != "active" ]] && [[ "$GEOM_EXTRA" != "$GEOM" ]]; then
					unset GEOM_WIN
				else
					notify-send window
				fi
				# TODO: take screenshot of window without window decoration
				ARGS=(-g "$GEOM")
			fi
			mkdir -p -- "$SCREENSHOTS_DIR"
			file="$SCREENSHOTS_DIR/$(date -- +"$SCREENSHOT_NAME_FORMAT").png"
			grim "${ARGS[@]}" "$file"
			magick "$file" -set geometry "$GEOM" "$file"
			wl-copy --type image/png <"$file" || xclip -selection clipboard -target "image/png" -i <"$file"
			[[ -n "$PICKER_PROC" ]] && kill -- "$PICKER_PROC"
			notify-send -i "$file" -- "Saved screenshot" "$file"
			return "$?"
		else
			echo "slurp or hyprpicker is already running, not taking a screenshot" >&2
		fi
	elif [[ "$1" == "color" ]] || [[ "$1" == "colour" ]]; then
		if ! pidof -s hyprpicker; then
			hex="$(hyprpicker)"
			if [[ -n "$hex" ]]; then
				magick -size 256x256 "xc:$hex" png:- >/tmp/color
				rgb="rgb($((0x${hex:1:2})), $((0x${hex:3:2})), $((0x${hex:5:2})))"
				echo "$hex"
				echo "$rgb"
				echo -n "$hex" | wl-copy
				notify-send -t 0 -i /tmp/color -- "$hex" "$rgb"
				return "$?"
			fi
		else
			echo "hyprpicker is already running, not taking a screenshot" >&2
		fi
	elif [[ "$1" == "check" ]]; then
		if ! type pidof; then
			echo "pidof not found" >&2
			return 1
		fi
		if ! type kill; then
			echo "kill not found" >&2
			return 1
		fi
		if ! type mkdir; then
			echo "mkdir not found" >&2
			return 1
		fi
		if ! type grim; then
			echo "grim not found" >&2
			return 1
		fi
		if ! type tee; then
			echo "tee not found" >&2
			return 1
		fi
		if ! type read; then
			echo "read not found" >&2
			return 1
		fi
		if ! type slurp; then
			echo "slurp not found" >&2
			return 1
		fi
		if ! type wl-copy && ! type xclip; then
			echo "both wl-copy and xclip not found" >&2
			return 1
		fi
		if ! type wl-copy; then echo "wl-copy not found, but xclip is"; fi
		if ! type xclip; then echo "xclip not found, but wl-copy is"; fi
		if ! type notify-send; then
			echo "notify-send not found" >&2
			return 1
		fi
		if ! type hyprctl; then
			echo "hyprctl not found" >&2
			return 1
		fi
		if ! type hyprpicker; then
			echo "hyprpicker not found" >&2
			return 1
		fi
		if ! type magick; then
			echo "magick not found" >&2
			return 1
		fi
		if ! type jq; then
			echo "jq not found" >&2
			return 1
		fi
		echo "all installed!"
		return 0
	else
		echo "Usage: screenshot (area|active|monitor|desktop|color|check)"
		echo "area: Select an area"
		echo "active: Active window"
		echo "monitor: Current monitor"
		echo "desktop: All monitors"
		echo "color: Color picker"
		echo "check: Check dependencies are installed"
	fi
	return 1
}
screenshot "$@"
