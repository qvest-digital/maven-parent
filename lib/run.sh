#!/usr/bin/env mksh
# -*- mode: sh -*-
#-
# Copyright © 2021
#	mirabilos <t.glaser@tarent.de>
# Licensor: Deutsche Telekom LLCTO
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
# Run executable JAR.

function makecmdline {
	# configure this to match the POM
	local mainclass=org.evolvis.tartools.mvnparent.examples.Main

	# define local variables first
	set +U
	local top exe cp x m2repo=~/.m2/repository

	# check mainclass begins with package or class
	if [[ -z $1 || $mainclass != [a-zA-Z]* ]]; then
		print -ru2 -- "[ERROR] This script, ${1@Q}, is misconfigured."
		exit 255
	fi

	# find directory this script is located in
	if ! top=$(realpath "$1/.."); then
		print -ru2 -- '[ERROR] Could not determine top-level directory.'
		exit 255
	fi
	shift
	# determine Maven repository path
	[[ -n $M2_REPO && -d $M2_REPO/. ]] && m2repo=$M2_REPO

	# figure out whether Maven resource filtering has gifted us with info
	cp=<<'	end-of-cp'
${runtime.classpath}
	end-of-cp
	exe=<<'	end-of-exe'
${runtime.jarname}
	end-of-exe

	# determine executable, either from above or by finding marker file
	exe=${exe%%*($'\n'|$'\r')}
	[[ $exe = [!\$]* ]] || exe=
	if [[ -n $exe && ! -e $exe ]]; then
		print -ru2 -- "[WARNING] $exe not found, looking around..."
		exe=
	fi
	[[ -n $exe ]] || for x in "$top"/target/*.cp; do
		if [[ -n $exe ]]; then
			print -ru2 -- '[ERROR] Found more than one JAR to run.'
			exit 255
		fi
		[[ -s $x ]] || break
		exe=${x%.cp}.jar
	done
	if [[ -z $exe ]]; then
		print -ru2 -- '[ERROR] Found no JAR to run.'
		exit 255
	fi
	if [[ ! -s $exe ]]; then
		print -ru2 -- "[ERROR] $exe not found."
		exit 255
	fi

	# determine JAR classpath, either from above or from the manifest
	set -U
	if [[ $cp = '$'* ]]; then
		if ! whence jjs >/dev/null 2>&1; then
			print -ru2 -- '[ERROR] jjs (from JRE) not installed.'
			exit 255
		fi
		cp=$(print -r -- 'echo(new java.util.jar.JarFile($ARG[1]).getManifest().getMainAttributes().getValue($ARG[0]));' | \
		    jjs -scripting - -- x-tartools-cp "$exe" 2>/dev/null) || cp=
		if [[ $cp != $'\u0086'* ]]; then
			print -ru2 -- '[ERROR] Could not retrieve classpath' \
			    "from $exe"
			exit 255
		fi
		cp=${cp#$'\u0086'}
	fi
	cp=${cp%%*($'\n'|$'\r'|$'\u0087')}
	cp=${cp//$'\u0095'/"/"}
	cp=${cp//$'\u009C'/":"}
	cp=${cp//$'\u0096'M2REPO$'\u0097'/"$m2repo"}
	set +U
	# determine run CLASSPATH
	cp=$exe${cp:+:$cp}${CLASSPATH:+:$CLASSPATH}
	# put together command line
	set -x -A _ java -cp "$cp" "$mainclass" "$@"
	# additional environment setup
	#export LD_LIBRARY_PATH=$top/target/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
}
makecmdline "$0" "$@"
set -x
exec "${_[@]}"
