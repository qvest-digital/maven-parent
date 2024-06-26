#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2018, 2020, 2021, 2022, 2024
#	mirabilos <t.glaser@qvest-digital.com>
#
# Provided that these terms and disclaimer and all copyright notices
# are retained or reproduced in an accompanying document, permission
# is granted to deal in this work without restriction, including un‐
# limited rights to use, publicly perform, distribute, sell, modify,
# merge, give away, or sublicence.
#
# This work is provided “AS IS” and WITHOUT WARRANTY of any kind, to
# the utmost extent permitted by applicable law, neither express nor
# implied; without malicious intent or gross negligence. In no event
# may a licensor, author or contributor be held liable for indirect,
# direct, other damage, loss, or other issues arising in any way out
# of dealing in the work, even if advised of the possibility of such
# damage or existence of a defect, except proven that it results out
# of said person’s immediate fault when using the work as intended.
#-
# Create mvnrepository.com URLs for all dependencies, extensions and
# Maven plugins, sorted and categorised, for up-to-date checks. With
# -r, raw undecorated output for easier concatenation is shown (only
# an empty line to separate parent POM extras). With -a do this, two
# empty lines for separation, for all POMs in the git working tree.

export LC_ALL=C
unset LANGUAGE

set -eU
set -o pipefail -o noglob
me=$(realpath "$0/..")
. "$me/assockit.ksh"
. "$me/progress-bar"

die() {
	print -ru2 -- "E: $*"
	exit 1
}

x=$(sed --posix 's/u\+/x/g' <<<'fubar fuu' 2>&1) && alias 'sed=sed --posix'
x=$(sed -e 's/u\+/x/g' -e 's/u/X/' <<<'fubar fuu' 2>&1)
case $?:$x {
(0:fXbar\ fuu) ;;
(*) die your sed is not POSIX compliant ;;
}

doall=0
rawout=0
while getopts "ar" ch; do
	case $ch {
	(a) doall=1 ;;
	(+a) doall=0 ;;
	(r) rawout=1 ;;
	(+r) rawout=0 ;;
	(*) die 'usage: mvnrepo.sh [-ar]' ;;
	}
done
shift $((OPTIND - 1))

if (( doall )); then
	it=$(realpath "$0")
	td=$(git rev-parse --show-toplevel)
	(( !rawout )) || set -- -r "$@"
	cd "$td"
	git ls-files -z | \
	    LC_ALL=C grep -z -e '^pom\.xml$' -e '/pom\.xml$' | \
	    LC_ALL=C sed -z -e 's!^!./!' -e 's!/pom\.xml$!!' -e 's!^\./!!' | \
	    LC_ALL=C sort -z | (
		IFS= read -d '' -r name || {
			print -ru2 "E: no POM found"
			exit 1
		}
		e=0
		while :; do
			print -ru2 -- "I: doing $name/"
			(cd "$name/" && exec "$it" "$@") || e=1
			print
			print
			IFS= read -d '' -r name || exit $e
		done
	)
	exit $?
fi

set -A grouping 'Parent' 'Project' 'Dependencies' 'Extensions' 'Plugins' 'Plugin Deps'

function xml2path {
	# thankfully only HT, CR, LF are, out of all C0 controls, valid in XML
	xmlstarlet tr "$me/mvnrepo.xsl" "$1" | { tr '\n' ''; print; } | \
	    sed -e 's!$!!' -e "s!'//!'//!g" -e "s!'\\\\''!'\\\\''!g" | \
	    tr '' '\n' | \
	    grep -E "^[^']*/(groupId|artifactId|version)='" >target/pom.xp
}

function extract {
	local line value base path p t x bron=$1 lines=$2

	# thankfully neither ' nor = are valid in XML names
	while IFS= read -r line; do
		draw_progress_bar
		if [[ $line = *''* ]]; then
			print -ru2 -- "W: Embedded newline in ${line@Q}"
			continue
		fi
		value=${line#*=}
		eval "value=$value" # trust our XSLT escaping code
		line=${line%%=*}
		base=${line##*/}
		line=${line%/*}
		asso_sets "$value" "$bron" "$line" "$base" || die asso_sets
	done <target/pom.xp
	asso_loadk "$bron" || die asso_loadk
	for path in "${asso_y[@]}"; do
		draw_progress_bar
		p=${path//'['+([0-9])']'}
		if [[ $p = //project/parent ]]; then
			t=0
		elif [[ $p = //project ]]; then
			t=1
		elif [[ $p = */extension ]]; then
			t=3
		elif [[ $p = */plugin/dependencies/dependency ]]; then
			t=5
		elif [[ $p = */plugin ]]; then
			t=4
		elif [[ $p = */dependencies/dependency ]]; then
			t=2
		elif [[ $p = */@(configuration|exclusions)/* ]]; then
			# skip well-known others silently
			continue
		else
			print -ru2 -- "W: Unknown XPath: $path"
			continue
		fi
		x=$(asso_getv "$bron" "$path" groupId) || x=
		[[ -n $x ]] || case $t {
		(1)	x=$(asso_getv "$bron" //project/parent groupId) || x=
			[[ -n $x ]] || die "No groupId for project or parent"
			;;
		(4)	x=org.apache.maven.plugins
			#print -ru2 -- "W: missing groupId for $path"
			;;
		(*)	die "missing groupId for $path"
			;;
		}
		[[ $x != */* ]] || die "wtf, groupId ${x@Q} for $path contains a slash"
		t+=/$x
		x=$(asso_getv "$bron" "$path" artifactId) || x=
		if [[ -n $x ]]; then
			t+=/$x
			[[ $x != */* ]] || die "wtf, artifactId ${x@Q} for $path contains a slash"
			x=$(asso_getv "$bron" "$path" version) || x=
			[[ $x != *'${'* && $x != *[\\/:\"\<\>\|?*]* ]] || x=
		fi
		[[ -z $x ]] || asso_sets "$x" versions "$t" || die asso_sets
		asso_setnull $lines "$t" || die asso_setnull
	done
}

function output {
	local lineno=-1 nlines line vsn lines=$1
	integer typ last=-1

	asso_loadk $lines || die asso_loadk
	nlines=${#asso_y[*]}
	(( nlines )) || (( rawout )) || print -r -- "(none)"
	while (( ++lineno < nlines )); do
		draw_progress_bar
		line=${asso_y[lineno]}
		vsn=$(asso_getv versions "$line") || vsn=
		[[ -z $vsn ]] || line+=/$vsn
		typ=${line::1}
		line=${line:2}
		(( rawout )) || if (( typ < 2 )); then
			print -nr -- "${grouping[typ]}: "
		elif (( typ != last )); then
			print
			print -r -- "${grouping[typ]}:"
		fi
		(( (last = typ), 1 ))
		print -r -- "https://mvnrepository.com/artifact/$line"
	done
}

function drop {
	local lineno=-1 nlines line vsn lines=$1 from=$2

	asso_loadk $lines || die asso_loadk
	nlines=${#asso_y[*]}
	while (( ++lineno < nlines )); do
		draw_progress_bar
		asso_unset $from "${asso_y[lineno]}" || die asso_unset
	done
}

if [[ ! -s pom.xml ]]; then
	print -ru2 E: no pom.xml found in current directory!
	exit 1
fi

mkdir -p target
rm -f target/effective-pom.xml
mvn -B -N help:effective-pom -Doutput=target/effective-pom.xml >&2 &
xml2path pom.xml

Lxp=$(wc -l <target/pom.xp)
# first estimate
Lxe=$((Lxp * 3 / 2))
Lop=$((Lxp / 3))
Loe=300 # outrageous, I know, but it makes things smoother
Lox=20 # similarily
init_progress_bar $((2*Lxp + 2 + 2*Lxe + Lop + Lop + Loe + Lox))

LN=$_cur_progress_bar
extract p plines
Lxpr=$((_cur_progress_bar - LN))

while [[ -n $(jobs) ]]; do wait; done
draw_progress_bar

xml2path target/effective-pom.xml

Lxe=$(wc -l <target/pom.xp)
draw_progress_bar
# re-estimate
Loe=$(( (Lxe-Lxp) / 3 ))
asso_loadk plines || die asso_loadk
Lop=${#asso_y[*]}
redo_progress_bar $((Lxpr + 2 + 2*Lxe + Lop + Lop + Loe + Lox))

LN=$_cur_progress_bar
extract e elines
Lxer=$((_cur_progress_bar - LN))

# recalculate
asso_loadk elines || die asso_loadk
Loe=${#asso_y[*]}
redo_progress_bar $((Lxpr + 2 + Lxer + Lop + Lop + Loe + Lox))

drop plines elines

Lox=0
if [[ -s src/main/ancillary/ckdep.ins ]] && grep \
    -F -q '<executable>src/main/ancillary/ckdep.sh</executable>' \
    target/effective-pom.xml; then
	while read first rest; do
		[[ $first != ?('#'*) ]] || continue
		first=${first#[+!]}
		first=${first/:/'/'}
		asso_loadv ins "$first" || asso_x=
		for rest in $rest; do
			asso_x+=" ${rest/:/'/'}"
		done
		asso_sets "$asso_x" ins "$first" || die asso_sets
	done <src/main/ancillary/ckdep.ins
	function enrich_lines {
		local lines=$1 line vsn typ inds ind

		asso_loadk $lines || die asso_loadk
		for line in "${asso_y[@]}"; do
			vsn=$(asso_getv versions "$line") || vsn=
			[[ -n $vsn ]] || continue
			typ=${line::1}
			enrich "${line:2}:$vsn"
		done
	}
	function enrich {
		local inds ind il

		inds=$(asso_getv ins "$1") || return 0
		for ind in $inds; do
			il=$typ/${ind%:*}
			if asso_isset "$lines" "$il"; then
				print -ru2 "W: preventing loop" \
				    "$typ/$1:$(asso_getv versions "$il" || \
				    print -nr "???") → $ind"
				continue
			fi
			asso_sets "${ind##*:}" versions "$il" || die asso_sets
			asso_setnull "$lines" "$il" || die asso_setnull
			let ++Lox
			enrich "$ind"
		done
	}
	enrich_lines plines
	enrich_lines elines
fi
rm -f target/effective-pom.xml target/pom.xp

asso_loadk elines || die asso_loadk
Loe=${#asso_y[*]}
redo_progress_bar $((Lxpr + 2 + Lxer + Lop + Lop + Loe + Lox))

output plines
print
(( rawout )) || print Effective POM extras:
output elines
done_progress_bar
