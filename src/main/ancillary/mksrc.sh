#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2016, 2018
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
LC_ALL=C; export LC_ALL
unset LANGUAGE
PS4='++ '
# check that we’re really run from mvn
if test -z "$MKSRC_RUN_FROM_MAVEN"; then
	echo >&2 "[ERROR] do not call me directly, I am only used by Maven"
	export -p
	exit 1
fi
# initialisation
set -e
set -o pipefail
cd "$(dirname "$0")/../../.."
rm -rf target/mksrc
mkdir -p target/mksrc

# performing a release?
if test x"$IS_M2RELEASEBUILD" = x"true"; then
	# fail the build if dependency licence review has a to-do item:
	# src/main/ancillary/ckdep.sh will fail the build when the list
	# was not up-to-date, so we only need to care about the current
	# state of the list (by default commented out):
	:||if grep -e ' TO''DO$' -e ' FA''IL$' src/main/ancillary/ckdep.lst; then
		echo >&2 "[ERROR] licence review incomplete"
		exit 1
	fi
fi

# check for source cleanliness
x=$(git status --porcelain)
if test -n "$x"; then
	echo >&2 "[ERROR] source tree not clean"
	echo >&2 "[INFO] git status output follows:"
	print -r -- "$x" | sed 's/^/[INFO]   /' >&2
	if test x"$IS_M2RELEASEBUILD" = x"true"; then
		:>target/mksrc/failed
		echo >&2 "[WARNING] maven-release-plugin prepare, continuing anyway"
		exit 0
	fi
	exit 1
fi

# enable verbosity
set -x

# copy git HEAD state
git ls-tree -r --name-only -z HEAD | sort -z | cpio -p0dlu target/mksrc/

# leave the rest to the maven-assembly-plugin
