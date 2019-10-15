#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2016, 2017, 2018, 2019
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
# Script to check dependencies

# initialisation
export LC_ALL=C
unset LANGUAGE
PS4='++ '
set -e
set -o pipefail
cd "$(dirname "$0")"

x=$(sed --posix 's/u\+/x/g' <<<'fubar fuu' 2>&1) && alias 'sed=sed --posix'
x=$(sed -e 's/u\+/x/g' -e 's/u/X/' <<<'fubar fuu' 2>&1)
case $?:$x {
(0:fXbar\ fuu) ;;
(*)
	print -ru2 -- '[ERROR] your sed is not POSIX compliant'
	exit 1 ;;
}

# get project metadata
<../../../pom.xml xmlstarlet sel \
    -N pom=http://maven.apache.org/POM/4.0.0 -T -t \
    -c /pom:project/pom:groupId -n \
    -c /pom:project/pom:artifactId -n \
    -c /pom:project/pom:version -n \
    |&
IFS= read -pr pgID
IFS= read -pr paID
IFS= read -pr pVSN
# check old file is sorted
sort -uo ckdep.tmp ckdep.lst
if cmp -s ckdep.lst ckdep.tmp; then
	abend=0
else
	print -ru2 -- '[WARNING] list of dependencies was not sorted!'
	cat ckdep.tmp >ckdep.lst
	abend=1
fi
# analyse Maven dependencies
(cd ../../.. && mvn -B dependency:list) 2>&1 | \
    tee /dev/stderr | sed -n \
    -e 's/ -- module .*$//' \
    -e '/^\[INFO]    '$pgID:$paID'/d' \
    -e '/^\[INFO]    \([^:]*\):\([^:]*\):jar:\([^:]*\):\([^:]*\)$/s//\1:\2 \3 \4 ok/p' \
    >ckdep.tmp
while IFS=' ' read ga v scope rest; do
	[[ $scope != @(compile|runtime) ]] || print -r -- ${ga/:/ } $v
done <ckdep.tmp | sort -u >ckdep.mvn.tmp
# add static dependencies from embedded files, for SecurityWatch
[[ -s ckdep.inc ]] && cat ckdep.inc >>ckdep.tmp
# make compile scope superset provided scope, and either superset test scope
x=$(sort -u <ckdep.tmp)
lastp=
lastt=
print -r -- "$x" | while IFS= read -r line; do
	[[ $line = "$lastp" ]] || [[ $line = "$lastt" ]] || print -r -- "$line"
	lastp=${line/ compile / provided }
	lastt=${lastp/ provided / test }
done >ckdep.tmp
# generate file with changed dependencies set to be a to-do item
# except we don’t licence-analyse test-only dependencies
{
	comm -13 ckdep.lst ckdep.tmp | sed 's/ ok$/ TO''DO/'
	comm -12 ckdep.lst ckdep.tmp
} | sed 's/ test TO''DO$/ test ok/' | sort -uo ckdep.tmp

# check if the list changed
if cmp -s ckdep.lst ckdep.tmp && cmp -s ckdep.mvn ckdep.mvn.tmp; then
	print -ru2 -- '[INFO] list of dependencies did not change'
else
	(diff -u ckdep.lst ckdep.tmp || :)
	# make the new list active
	mv -f ckdep.mvn.tmp ckdep.mvn
	mv -f ckdep.tmp ckdep.lst
	# inform the user
	print -ru2 -- '[WARNING] list of dependencies changed!'
	abend=1
fi
rm -f ckdep.tmp ckdep.mvn.tmp
# check if anything needs to be committed
if (( abend )); then
	print -ru2 -- '[ERROR] please commit the changed ckdep.{lst,mvn} files!'
	exit 1
fi

# fail a release build if dependency licence review has a to-do item
[[ $IS_M2RELEASEBUILD = true ]] && \
    if grep -e ' TO''DO$' -e ' FA''IL$' ckdep.lst; then
	print -ru2 -- '[ERROR] licence review incomplete'
	exit 1
fi

exit 0
