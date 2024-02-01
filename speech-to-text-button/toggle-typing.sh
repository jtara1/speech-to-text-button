#!/usr/bin/env bash

### functions
update_sess_name() {
  base_sess_name=speech-to-text
  sess_name=$(screen -list | grep -oP "\d+\.$base_sess_name" || echo "$base_sess_name")

  state_file=/tmp/"$sess_name"
  state=""
  [[ "$sess_name" != "$base_sess_name" && -f "$state_file" ]] && state=$(cat "$state_file")
}

end_listening() {
	echo $'\n'--- ending
	# TODO: improve by allowing this command and nerd-dictation begin command to block until they both exit instead of the `sleep 5`
  screen -S "$sess_name" -X stuff "nix-shell \
    $dir/python.nix \
    --command $dir/nerd-dictation\ end^M"

	sleep 3
  screen -S "$sess_name" -X quit
  echo --- ended
}

### script
dir="$(dirname "$(readlink -f "$0")")"
#echo dir is "$dir"
update_sess_name
[ "$1" = "end" ] && end_listening && exit 0

case "$state" in
  "")
    echo $'\n'--- cold start - can take ~5GB RAM depending on model loaded and take ~5 seconds to startup
    echo --- listening for speech to text soon ...

    screen -dmS "$sess_name"
    update_sess_name

		# runs nix-shell in background running nerd-dictation in background
		# to enable screen session to accept more input as commands
    screen -S "$sess_name" -X stuff "nix-shell $dir/python.nix \
      --run $dir/nerd-dictation\ begin\ --numbers-as-digits\ --numbers-no-suffix\ &^M"

    echo running > "$state_file"
    exit 0
  ;;

  "running")
    echo $'\n'--- pausing
    screen -S "$sess_name" -X stuff "nix-shell \
      $dir/python.nix \
      --command $dir/nerd-dictation\ suspend^M"

    echo suspended > "$state_file"
    exit 0
  ;;

  "suspended")
    echo $'\n'--- resuming
    screen -S "$sess_name" -X stuff "nix-shell \
      $dir/python.nix \
      --command $dir/nerd-dictation\ resume^M"

    echo running > "$state_file"
    exit 0
  ;;

  *)
    echo unknown state: "$state"
    exit 1
  ;;
esac
