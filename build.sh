#!/usr/bin/bash
declare -A colors=([light]=2 [heavy]=4) current=([mcVerFix]=mc13)
[[ ${colors[$1]} ]] && modes=("$1") && set -- "${@:2}" || modes=("${!colors[@]}")

setMode() {
	local mode=$1
	if [[ -d ./assets/minecraft/models/block/3d/mode/$mode ]]; then
		for available in "${!colors[@]}"; do
			if [[ ! -d ./assets/minecraft/models/block/3d/mode/$available ]]; then
				mv ./assets/minecraft/models/block/3d/mode/current ./assets/minecraft/models/block/3d/mode/$available
				[[ ${current[mode]} ]] || current[mode]=$available
				break
			fi
		done
		mv ./assets/minecraft/models/block/3d/mode/$mode ./assets/minecraft/models/block/3d/mode/current
	fi

	local info="§${colors[$mode]}$mode\""
	grep "$info" ./pack.mcmeta > /dev/null || sed -i "4s/§.*\"/$info/" ./pack.mcmeta
}

light() {
	if [[ $1 == setup ]]; then
		setMode light
		cp ./assets/minecraft/blockstates/spruce_leaves.json /tmp/spruce_leaves.json
		# strip cones from spruce leaves
		sed -i '29,47d' ./assets/minecraft/blockstates/spruce_leaves.json
	else
		cp /tmp/spruce_leaves.json ./assets/minecraft/blockstates/spruce_leaves.json
	fi
}

heavy() {
	[[ $1 == setup ]] && setMode heavy
}

declare -A mcVerFix=([mc13]='1.13-1.20.1' [mc20_4]='1.20.4+')
if [[ $1 && ${mcVerFix["$1"]} ]]; then
	mcVer=("$1")
	set -- "${@:2}"
elif [[ $1 == 1.13* || $1 == 1.20.4* || $1 == old || $1 == grass || $1 == new ]]; then
	[[ $1 == old || $1 == 1.13* ]] && mcVer=(mc13) || mcVer=(mc20_4)
	set -- "${@:2}"
else
	mcVer=("${mcVerFix[@]}")
fi

mc13() {
	:
}

mc20_4() {
	local blockstate=./assets/minecraft/blockstates/grass.json
	local grass=(./assets/minecraft/models/block/grass/{0..4}.json ./assets/minecraft/models/block/tall_grass_bottom.json)
	if [[ $1 == setup ]]; then
		mv "$blockstate" "${blockstate/grass/short_grass}"
		for f in "${grass[@]}"; do
			sed -i 's,"block/grass","block/short_grass",g' "$f"
		done
		sed -i 's,"pack_format": 15,"pack_format": 22,' ./pack.mcmeta
	else
		mv "${blockstate/grass/short_grass}" "$blockstate"
		for f in "${grass[@]}"; do
			sed -i 's,"block/short_grass","block/grass",g' "$f"
		done
		sed -i 's,"pack_format": 22,"pack_format": 15,' ./pack.mcmeta
	fi
}

fmtInplace() {
	prettier --use-tabs --tab-width 2 --no-bracket-spacing --print-width 200 "$1" > "$2"
	diff -q "$1" "$2" || cp "$2" "$1"
}

format() {
	[[ $root ]] || local root=${1%/*}
	mkdir -p /tmp/"${1#$root}"
	for f in "$1"/*; do
		if [[ -d $f ]]; then
			format "$f"
		elif [[ $f == *.json ]]; then
			if (($(jobs -r | wc -l) > 14)); then
				fmtInplace "$f" "/tmp/${f#$root}"
			else
				fmtInplace "$f" "/tmp/${f#$root}" &
			fi
		else
			cp "$f" /tmp/"${f#$root}"
		fi
	done
}

if [[ $1 == fmt || $1 == format ]]; then
	((CPU = $(lscpu | sed -n 's/.*CPU:\s\+\([0-9]\+\)$/\1/p' | head -n 1) * 5 / 6))
	format "${2%/}" && wait
else
	for mode in ${modes[@]}; do
		$mode setup
		for ver in ${mcVer[@]}; do
			$ver setup
			7z a "EF_${mode^}_${mcVerFix["$ver"]}.zip" ./pack.png ./pack.mcmeta ./assets/
			$ver reset
		done
		$mode reset
	done

	${current[mode]:-heavy} setup
	${current[mcVerFix]:-mc13} setup
fi
