#!/usr/bin/bash

###### JSON model/blockstate formatting

fmtInplace() {
	prettier --use-tabs --tab-width 2 --no-bracket-spacing --print-width 200 "$1" >"$2"
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
	exit 0
fi

###### Pack building

### Detail-setting block

declare -A detailColor=([light]=2 [heavy]=4)

light() {
	if [[ ! -f /tmp/wheat.json ]]; then
		# use default wheat model
		mv ./assets/minecraft/models/block/wheat_stage7* /tmp/
		mv ./assets/minecraft/blockstates/wheat.json /tmp/

		# strip cones from spruce leaves
		cp ./assets/minecraft/blockstates/spruce_leaves.json /tmp/spruce_leaves.json
		sed -i '29,47d' ./assets/minecraft/blockstates/spruce_leaves.json
	fi
}

heavy() {
	if [[ -f /tmp/wheat.json ]]; then
		mv /tmp/wheat.json ./assets/minecraft/blockstates/
		mv /tmp/wheat_stage7* ./assets/minecraft/models/block/
		mv /tmp/spruce_leaves.json ./assets/minecraft/blockstates/spruce_leaves.json
	fi
}

setDetail() {
	local detail=$1
	if [[ -d ./assets/minecraft/models/block/3d/detail/$detail ]]; then
		for available in "${!detailColor[@]}"; do
			# find the currently active detail and move it to its name to deactivate it
			if [[ ! -d ./assets/minecraft/models/block/3d/detail/$available ]]; then
				mv ./assets/minecraft/models/block/3d/detail/current ./assets/minecraft/models/block/3d/detail/$available
				break
			fi
		done
		# set selected detail as active
		mv ./assets/minecraft/models/block/3d/detail/$detail ./assets/minecraft/models/block/3d/detail/current
	fi

	local info="§${detailColor[$detail]}$detail\""
	grep "$info" ./pack.mcmeta >/dev/null || sed -i "4s/§.*\"/$info/" ./pack.mcmeta

	"$detail"
}

detailResolve() {
	if [[ ${detailColor["${1:-_}"]} ]]; then
		echo "$1"
	else
		echo "${!detailColor[@]}"
		return 1
	fi
}

### Version-setting block

declare -A mcVersionRange=([mc13]='1.13-1.20.1' [mc20_4]='1.20.4+')

setGrassVersion() {
	local blockstate=(./assets/minecraft/blockstates/*grass.json)
	local grass=(
		./assets/minecraft/models/block/grass/*.json # only 0..4 currently need texture renaming
		./assets/minecraft/models/block/tall_grass_bottom.json
	)

	[[ $1 == mc13 ]] && local from=short_grass to=grass || local from=grass to=short_grass

	if [[ $blockstate != */"${to}.json" ]]; then
		mv "$blockstate" "${blockstate/"$from"/$to}"
		for f in "${grass[@]}"; do
			sed -i "s,\"block/${from}\",\"block/${to}\",g" "$f"
		done
	fi
}

declare -A packFormat=([mc13]=15 [mc20_4]=26)
setPackFormat() {
	sed -i 's,"pack_format": [0-9]\+,"pack_format": '"${packFormat["$1"]}," ./pack.mcmeta
}

setMcVersion() {
	local version=$1
	setGrassVersion "$version"
	setPackFormat "$version"
}

mcVersionResolve() {
	declare -A mapping=([old]=mc13 ['pre-1.20.4']=mc13 [default]=mc20_4 [new]=mc20_4)
	for key in "${!mcVersionRange[@]}"; do
		mapping["${mcVersionRange[$key]}"]=$key
	done

	if [[ ${mapping["${1:-_}"]} ]]; then
		echo "${mapping["$1"]}"
	elif [[ ${mcVersionRange["${1:-_}"]} ]]; then
		echo "$1"
	else
		echo "${!mcVersionRange[@]}"
		return 1
	fi
}

### Determine combinations to create

declare -A defaultState=([detail]=heavy [mcVersion]=mc20_4)

details=($(detailResolve "$1")) && shift
mcVersions=($(mcVersionResolve "$1")) && shift
if (($# > 0)); then
	echo "Error: Unrecognized arguments: $*"
	echo "Usage: $0 [detail] [mcVersion]"
	echo
	echo "Parsed result:"
	echo "Selected details: ${details[*]}"
	echo "Selected versions: ${versions[*]}"
	exit 1
fi >&2

for DETAIL in "${details[@]}"; do
	setDetail "$DETAIL"

	for MC_VERSION in "${mcVersions[@]}"; do
		setMcVersion "$MC_VERSION"

		7z a "EF_${DETAIL^}_${mcVersionRange["$MC_VERSION"]}.zip" ./pack.png ./pack.mcmeta ./assets/
	done
done

setDetail "${defaultState['detail']}"
setMcVersion "${defaultState['mcVersion']}"
