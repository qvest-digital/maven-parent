#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2016, 2017, 2018, 2019, 2020
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
unset GZIP
set -e
set -o pipefail

errmsg() (
	print -ru2 -- "[ERROR] $1"
	shift
	IFS=$'\n'
	set -o noglob
	set -- $*
	for x in "$@"; do
		print -ru2 -- "[INFO] $x"
	done
)
function die {
	errmsg "$@"
	exit 1
}

# check that we’re really run from mvn
[[ -n $MKSRC_RUN_FROM_MAVEN ]] || die \
    'do not call me directly, I am only used by Maven' \
    "$(export -p)"
# initialisation
cd "$(dirname "$0")"
. ./cksrc.sh
ancdir=$PWD
cd "./$parentpompath"
ancdir=${ancdir#"$PWD"/}
[[ ! -e failed ]] || die \
    'do not build from incomplete/dirty tree' \
    'a previous mksrc failed and you used its result'

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
	# if the dependency list for licence review still has a to-do or
	# fail item, fail the build (we can handle the current list sin‐
	# ce ./ckdep.sh already fails the build for not up-to-date list)
	if grep -e ' TO''DO$' -e ' FA''IL$' "$ancdir"/ckdep.lst; then
		die 'licence review incomplete'
	fi
fi

# check for source cleanliness
x=$(git status --porcelain)
if [[ -n $x ]]; then
	errmsg 'source tree not clean; “git status” output follows:' "$x"
	if [[ $IS_M2RELEASEBUILD = true ]]; then
		:>"$tgname"/failed
		:>"$tbname"/failed
		print -ru2 -- "[WARNING] maven-release-plugin prepare, continuing anyway"
		cd "$tbname"
		paxtar -M dist -cf - "$tzname"/f* | gzip -n9 >"../$tzname.tgz"
		rm -f src.tgz
		ln "../$tzname.tgz" src.tgz
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

# omit what will anyway end up in depsrcs
if [[ $drop_depsrc_from_mksrc != 0 ]]; then
	rm -rf "$tgname/$depsrcpath"
fi

# create source tarball
cd "$tbname"
find "$tzname" -print0 | TZ=UTC xargs -0r touch -h -t "$ts" --
find "$tzname" \( -type f -o -type l \) -print0 | sort -z | \
    paxcpio -oC512 -0 -Hustar -Mdist | gzip -n9 >"../$tzname.tgz"
rm -rf "$tzname"  # to save space
rm -f src.tgz
ln "../$tzname.tgz" src.tgz

# shove dependencies’ sources into place
rm -f deps-src.zip
cd ..
found=0
for x in *-sources-of-dependencies.zip; do
	[[ -e $x && -f $x && ! -h $x && -s $x ]] || continue
	if (( found++ )); then
		errmsg 'multiple depsrcs archives found:' \
		    "$(ls -l *-sources-of-dependencies.zip)"
		break
	fi
	fn=$x
done
(( found == 1 )) || die 'could not link dependency sources'
ln "$fn" mksrc/deps-src.zip
