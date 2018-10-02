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
# Pipe a Maven POM <dependencies> or <exclusions> element’s content,
# without the surrounding grouping element, into this to sort them.

LC_ALL=C; export LC_ALL
unset LANGUAGE

set -e
cr=$'\r'
lf=$'\n'
(( ${#cr} == 1 ))
set -o pipefail

# offsets in element array
otype=0
oG=1
oA=2
oV=5
oType=4
oClassifier=3
oScope=6
oSystemPath=8
oExclusions=9
oOptional=7
oprecomments=10
oincomments=11

exec 4<&0
(
	print '<toplevel>'
	tr "$cr" "$lf" <&4
	print '</toplevel>'
) | xmlstarlet fo -e UTF-8 -n - |&

die() {
	print -ru2 -- "E: $*"
	print -ru2 -- "N: line: ${line@Q}"
	exit 1
}

set -A sortlines
IFS= read -pr line
[[ $line = '<?xml version="1.0" encoding="UTF-8"?>' ]] || \
    die unexpected first line not XML declaration
IFS= read -pr line
[[ $line = '<toplevel>' ]] || die unexpected second line not start tag

set -A el
state=0
while IFS= read -pr line; do
	case $state:$line {
	(0:'<!--'*)
		el[oprecomments]+=$line ;;
	(1:'<!--'*)
		el[oincomments]+=$line ;;
	(0:'</toplevel>')
		state=9 ;;
	(0:'<dependency>')
		el[otype]=0
		state=1 ;;
	(0:'<exclusion>')
		el[otype]=1
		state=1 ;;
	(1:'</dependency>'|1:'</exclusion>')
		sortlines+=("${el[0]}$cr${el[1]}$cr${el[2]}$cr${el[3]}$cr${el[4]}$cr${el[5]}$cr${el[6]}$cr${el[7]}$cr${el[8]}$cr${el[9]}$cr${el[10]}$cr${el[11]}")
		set -A el
		state=0 ;;
	(1:'<'@(groupId|artifactId|version|type|classifier|scope|systemPath|exclusions|optional)'/>')
		;;
	(1:'<groupId>'*'</groupId>')
		x=${line#'<groupId>'}
		el[oG]=${x%'</groupId>'} ;;
	(1:'<artifactId>'*'</artifactId>')
		x=${line#'<artifactId>'}
		el[oA]=${x%'</artifactId>'} ;;
	(1:'<version>'*'</version>')
		x=${line#'<version>'}
		el[oV]=${x%'</version>'} ;;
	(1:'<type>'*'</type>')
		x=${line#'<type>'}
		el[oType]=${x%'</type>'} ;;
	(1:'<classifier>'*'</classifier>')
		x=${line#'<classifier>'}
		el[oClassifier]=${x%'</classifier>'} ;;
	(1:'<scope>'*'</scope>')
		x=${line#'<scope>'}
		el[oScope]=${x%'</scope>'} ;;
	(1:'<systemPath>'*'</systemPath>')
		x=${line#'<systemPath>'}
		el[oSystemPath]=${x%'</systemPath>'} ;;
	(1:'<optional>'*'</optional>')
		x=${line#'<optional>'}
		el[oOptional]=${x%'</optional>'} ;;
	(1:'<exclusions>')
		x=
		while IFS= read -pr line; do
			[[ $line = '</exclusions>' ]] && break
			x+=$line
		done
		[[ $line = '</exclusions>' ]] || die unterminated exclusions
		line=$x
		x=$(mksh "$0" <<<"$line") || die could not sort sub-exclusions
		el[oExclusions]=${x//"$lf"} ;;
	(*)
		die illegal line in state $state ;;
	}
done
(( state == 9 )) || die unexpected last line not end tag

for x in "${sortlines[@]}"; do
	print -r -- "$x"
done | sort -u |&

set -A beg -- '<dependency>' '<exclusion>'
set -A end -- '</dependency>' '</exclusion>'
while IFS="$cr" read -prA el; do
	[[ -n ${el[oprecomments]} ]] && print -r -- "${el[oprecomments]}"
	print -r -- "${beg[el[otype]]}"
	[[ -n ${el[oincomments]} ]] && print -r -- "${el[oincomments]}"
	[[ -n ${el[oG]} ]] && print -r -- "<groupId>${el[oG]}</groupId>"
	[[ -n ${el[oA]} ]] && print -r -- "<artifactId>${el[oA]}</artifactId>"
	[[ -n ${el[oV]} ]] && print -r -- "<version>${el[oV]}</version>"
	[[ -n ${el[oType]} ]] && print -r -- "<type>${el[oType]}</type>"
	[[ -n ${el[oClassifier]} ]] && print -r -- "<classifier>${el[oClassifier]}</classifier>"
	[[ -n ${el[oScope]} ]] && print -r -- "<scope>${el[oScope]}</scope>"
	[[ -n ${el[oSystemPath]} ]] && print -r -- "<systemPath>${el[oSystemPath]}</systemPath>"
	[[ -n ${el[oExclusions]} ]] && print -r -- "<exclusions>${el[oExclusions]}</exclusions>"
	[[ -n ${el[oOptional]} ]] && print -r -- "<optional>${el[oOptional]}</optional>"
	print -r -- "${end[el[otype]]}"
done

exit 0
