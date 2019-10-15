#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2018, 2019
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
# Build tarball containing source JARs of dependencies.

# initialisation
LC_ALL=C; export LC_ALL
unset LANGUAGE
PS4='++ '
# check that we’re really run from mvn
if test -z "$DEPSRC_RUN_FROM_MAVEN"; then
	echo >&2 "[ERROR] do not call me directly, I am only used by Maven"
	export -p
	exit 1
fi
# initialisation
set -e
set -o pipefail
cd "$(dirname "$0")/.."
mkdir -p target
rm -rf target/dep-srcs*

#if [[ ! -d release/depsrc/. ]]; then
#	# look at this script further below for a list of files
#	print -ru2 -- "[ERROR] add release/depsrc/ from deps-src.zip"
#	exit 1
#fi

vsn=$(<pom.xml xmlstarlet sel \
    -N pom=http://maven.apache.org/POM/4.0.0 \
    -T -t -c /pom:project/pom:version)

exec >target/pom-srcs.xml
cat <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>
	<parent>
		<groupId>org.evolvis.veraweb</groupId>
		<artifactId>veraweb-parent</artifactId>
		<version>$vsn</version>
		<relativePath>../</relativePath>
	</parent>
	<artifactId>release-sources</artifactId>
	<packaging>jar</packaging>
	<dependencyManagement>
		<dependencies>
EOF
while read g a v; do
	cat <<EOF
			<dependency>
				<groupId>$g</groupId>
				<artifactId>$a</artifactId>
				<version>$v</version>
EOF
#	[[ $g:$a = org.evolvis.tartools.example:example-dependency ]] && cat <<EOF
#				<exclusions>
#					<exclusion>
#						<groupId>org.evolvis.tartools.example</groupId>
#						<artifactId>unwanted-recursive-dependency</artifactId>
#					</exclusion>
#				</exclusions>
#EOF
	cat <<EOF
			</dependency>
EOF
done <release/ckdep.mvn
cat <<\EOF
		</dependencies>
	</dependencyManagement>
	<dependencies>
EOF
while read g a v; do
	# here: exclude webjars without meaningful sources
	#if [[ $g = org.webjars.@(bower|bowergithub|npm)?(.*) ]]; then
	#	# comment here on where to find the source
	#	continue
	#fi
	cat <<EOF
		<dependency>
			<groupId>$g</groupId>
			<artifactId>$a</artifactId>
			<version>$v</version>
		</dependency>
EOF
done <release/ckdep.mvn
cat <<\EOF
	</dependencies>
</project>
EOF
exec >&2

set -x
mkdir target/dep-srcs
mvn -B -f target/pom-srcs.xml \
    -DexcludeTransitive=true -DoutputDirectory="$PWD/target/dep-srcs" \
    -Dclassifier=sources -Dmdep.useRepositoryLayout=true \
    dependency:copy-dependencies

: diff between actual and expected list
set +x

function doit {
	local f=release/depsrc/$1 g=${2//./'/'} a=$3 v=$4

	if [[ -d target/dep-srcs/$g/$a ]]; then
		print -ru2 -- "[ERROR] missing dependency sources unexpectedly found"
		exit 1
	fi
	mkdir -p target/dep-srcs/$g/$a
	mkdir target/dep-srcs/$g/$a/$v
	cp $f target/dep-srcs/$g/$a/$v/
}

# this is the list of files
#doit antlr-2.7.7.tar.gz \
#    antlr antlr 2.7.7

set -A exclusions
set -A inclusions
inclusions+=(-e '^# dummy, only needed if this array is empty otherwise$')
exclusions+=(-e '^# dummy$')
find target/dep-srcs/ -type f | \
    fgrep -v -e _remote.repositories -e maven-metadata-local.xml | \
    while IFS= read -r x; do
		x=${x#target/dep-srcs/}
		x=${x%/*}
		v=${x##*/}
		x=${x%/*}
		p=${x##*/}
		x=${x%/*}
		print -r -- ${x//'/'/.} $p $v
done | sort | grep -v "${exclusions[@]}" >target/dep-srcs.actual
grep -v "${inclusions[@]}" <release/ckdep.mvn >target/dep-srcs.expected
diff -u target/dep-srcs.actual target/dep-srcs.expected
print -r -- "[INFO] release/depsrc.sh finished"
# leave the rest to the maven-assembly-plugin
