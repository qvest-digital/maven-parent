#!/bin/mksh
# © mirabilos Ⓕ MirBSD

set -exo pipefail
mvn -B -f allplugins.xml dependency:resolve-plugins -DoutputFile=allplugins.tmp
last='???invalid???'
m() {
	t=$1
	shift

	if [[ $t = = ]]; then
		last="$*"
	else
		print -r -- "$last	$*"
	fi
}
{
	eval "$(sed -n '/^   /s//m = /p' allplugins.tmp | sed 's/=    /: /')"
} | sort -u >allplugins.out
rm allplugins.tmp
