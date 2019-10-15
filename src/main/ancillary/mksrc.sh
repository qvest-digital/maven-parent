#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2016, 2018, 2019
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
# Build-specific tool to create a tarball of the entire source code.

# initialisation
export LC_ALL=C
unset LANGUAGE
PS4='++ '
# check that we’re really run from mvn
if [[ -z $MKSRC_RUN_FROM_MAVEN ]]; then
	print -ru2 -- "[ERROR] do not call me directly, I am only used by Maven"
	export -p
	exit 1
fi
# initialisation
unset GZIP
set -e
set -o pipefail
cd "$(dirname "$0")/../../.."
if [[ -e failed ]]; then
	print -ru2 -- "[ERROR] do not build from incomplete/dirty tree"
	print -ru2 -- "[INFO] a previous mksrc failed and you used its result"
	exit 1
fi
# get project metadata
<pom.xml xmlstarlet sel \
    -N pom=http://maven.apache.org/POM/4.0.0 -T -t \
    -c /pom:project/pom:groupId -n \
    -c /pom:project/pom:artifactId -n \
    -c /pom:project/pom:version -n \
    |&
IFS= read -pr pgID
IFS= read -pr paID
IFS= read -pr pVSN
# create base directory
tbname=target/mksrc
tzname=$paID-$pVSN-source
tgname=$tbname/$tzname
rm -rf "$tgname"
mkdir -p "$tgname"

# performing a release?
if [[ $IS_M2RELEASEBUILD = true ]]; then
	# fail the build if dependency licence review has a to-do item:
	# src/main/ancillary/ckdep.sh will fail the build when the list
	# was not up-to-date, so we check only the current list
	if grep -e ' TO''DO$' -e ' FA''IL$' src/main/ancillary/ckdep.lst; then
		print -ru2 -- "[ERROR] licence review incomplete"
		exit 1
	fi
fi

# check for source cleanliness
x=$(git status --porcelain)
if [[ -n $x ]]; then
	print -ru2 -- "[ERROR] source tree not clean"
	print -ru2 -- "[INFO] git status output follows:"
	print -r -- "$x" | sed 's/^/[INFO]   /' >&2
	if [[ $IS_M2RELEASEBUILD = true ]]; then
		:>"$tgname"/failed
		:>"$tbname"/failed
		print -ru2 -- "[WARNING] maven-release-plugin prepare, continuing anyway"
		cd "$tbname"
		paxtar -M dist -cf - "$tzname"/f* | gzip -n9 >"../$tzname.tgz"
		exit 0
	fi
	exit 1
fi

# enable verbosity
set -x

# copy git HEAD state
git ls-tree -r --name-only -z HEAD | sort -z | paxcpio -p0du "$tgname/"
ts=$(TZ=UTC git show --no-patch --pretty=format:%ad \
    --date=format-local:%Y%m%d%H%M.%S)

# create source tarball
cd "$tbname"
find "$tzname" -print0 | TZ=UTC xargs -0r touch -h -t "$ts" --
find "$tzname" \( -type f -o -type l \) -print0 | sort -z | \
    paxcpio -oC512 -0 -Hustar -Mdist | gzip -n9 >"../$tzname.tgz"
rm -rf "$tzname"  # to save space
