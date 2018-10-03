#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2018
#	mirabilos <t.glaser@tarent.de>
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
# Maven plugins, sorted and categorised, for up-to-date checks.

LC_ALL=C; export LC_ALL
unset LANGUAGE

set -e
set -o pipefail
me=$(realpath "$0/..")
. "$me/assockit.ksh"

die() {
	print -ru2 -- "E: $*"
	exit 1
}

set -A grouping 'Parent' 'Project' 'Dependencies' 'Extensions' 'Plugins' 'Plugin Deps'
function extract {
	local line value base path p t x bron=$1 lines=$2

	# thankfully neither ' nor = are valid in XML names
	exec 4>&0
	xmlstarlet tr "$me/tmp.xsl" <&4 | \
	    egrep "^[^']*/(groupId|artifactId|version)='" |&
	set +e
	while IFS= read -pr line; do
		value=${line#*=}
		eval "value=$value" # trust our XSLT escaping code
		(( $? )) && die "Error reading value from line ${line@Q}"
		line=${line%%=*}
		base=${line##*/}
		line=${line%/*}
		asso_sets "$value" "$bron" "$line" "$base"
	done
	asso_loadk "$bron"
	for path in "${asso_y[@]}"; do
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
		elif [[ $p = */configuration/* ]]; then
			# skip well-known others silently
			continue
		else
			print -ru2 -- "W: Unknown XPath: $path"
			continue
		fi
		t+=/${grouping[$t]}
		x=$(asso_getv "$bron" "$path" groupId)
		[[ -n $x ]] || case $t {
		(1)	x=$(asso_getv "$bron" //project/parent groupId)
			[[ -n $x ]] || die "No groupId for project or parent"
			;;
		(4)	x=org.apache.maven.plugins
			print -ru2 -- "W: missing groupId for $path"
			;;
		(*)	die "missing groupId for $path"
			;;
		}
		[[ $x = */* ]] && die "wtf, groupId ${x@Q} for $path contains a slash"
		t+=/$x
		x=$(asso_getv "$bron" "$path" artifactId)
		if [[ -n $x ]]; then
			t+=/$x
			[[ $x = */* ]] && die "wtf, artifactId ${x@Q} for $path contains a slash"
			x=$(asso_getv "$bron" "$path" version)
			[[ -z $x || $x = *'${'* || $x = *[\\/:\"\<\>\|?*]* ]] || t+=/$x
		fi
		asso_setnull $lines "$t"
	done
	set -e
}

function output {
	local lineno=-1 nlines lines=$1

	set +e
	asso_loadk $lines
	set -e
	nlines=${#asso_y[*]}
	while (( ++lineno < nlines )); do
		print -r -- "${asso_y[lineno]}"
	done
}

extract p plines <pom.xml
output plines | sort -u
