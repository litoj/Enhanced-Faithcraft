#!/usr/bin/bash
declare -A colors=([light]=2 [heavy]=4) # [medium]=6
[[ $1 ]] && todo=("$@") || todo=("${!colors[@]}")

light() {
	if [[ $1 == setup ]]; then
		cp ./assets/minecraft/blockstates/spruce_leaves.json /tmp/spruce_leaves.json
		# strip cones from spruce leaves
		sed -i '29,47d' ./assets/minecraft/blockstates/spruce_leaves.json
	elif [[ $1 == reset ]]; then
		cp /tmp/spruce_leaves.json ./assets/minecraft/blockstates/spruce_leaves.json
	fi
}

heavy() {
	:
}

setVersion() {
	local version=$1
	if [[ -d ./assets/minecraft/models/block/3d/version/$version ]]; then
		for available in "${!colors[@]}"; do
			if [[ ! -d ./assets/minecraft/models/block/3d/version/$available ]]; then
				mv ./assets/minecraft/models/block/3d/version/current ./assets/minecraft/models/block/3d/version/$available
				[[ $current ]] || current=$available
				break
			fi
		done
		mv ./assets/minecraft/models/block/3d/version/$version ./assets/minecraft/models/block/3d/version/current
	fi

	local info="§${colors[$version]}$version\""
	grep "$info" ./pack.mcmeta > /dev/null || sed -i "4s/§.*\"/$info/" ./pack.mcmeta
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
	for version in ${todo[@]}; do
		setVersion $version
		$version setup
		7z a "EF-${version^}.zip" ./pack.png ./pack.mcmeta ./assets/
		$version reset
	done

	setVersion ${current:-heavy}
fi
