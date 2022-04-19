package org.evolvis.tartools.mvnparent.examples;

/*-
 * Copyright © 2016, 2018, 2019, 2020, 2021, 2022
 *	mirabilos (t.glaser@tarent.de)
 * Licensor: tarent solutions GmbH, Bonn
 *
 * Provided that these terms and disclaimer and all copyright notices
 * are retained or reproduced in an accompanying document, permission
 * is granted to deal in this work without restriction, including un‐
 * limited rights to use, publicly perform, distribute, sell, modify,
 * merge, give away, or sublicence.
 *
 * This work is provided “AS IS” and WITHOUT WARRANTY of any kind, to
 * the utmost extent permitted by applicable law, neither express nor
 * implied; without malicious intent or gross negligence. In no event
 * may a licensor, author or contributor be held liable for indirect,
 * direct, other damage, loss, or other issues arising in any way out
 * of dealing in the work, even if advised of the possibility of such
 * damage or existence of a defect, except proven that it results out
 * of said person’s immediate fault when using the work as intended.
 */

import org.evolvis.tartools.mvnparent.InitialiseLogging;

import java.util.logging.Logger;

/**
 * <p>Example “Main” class showing how to use InitialiseJDK14Logging</p>
 *
 * <p>Put “.”, another directory with logging.properties, or a JAR file
 * that contains logging.properties, onto the classpath in order to run
 * this, for example:</p><pre>
 * $ CLASSPATH=../target/bs-3.0-tests.jar ./run.sh
 * </pre>
 *
 * <p>This will run:</p><pre>
 * java -cp target/lib-3.0.jar:../target/bs-3.0-tests.jar \
 *     org.evolvis.tartools.mvnparent.examples.Main
 * </pre>
 *
 * <p>Adjust the version numbers accordingly, of course.</p>
 *
 * @author mirabilos (t.glaser@tarent.de)
 */
public final class Main {

// note this MUST NOT be replaced by Lombok @Log in this class ONLY
private static final Logger LOGGER;

/* initialise logging subsystem (must be done before creating a LOGGER) */
static {
	InitialiseLogging.InitialiseJDK14Logging();
	LOGGER = Logger.getLogger(Main.class.getName());
}

/**
 * <p>Example CLI main entry point.</p>
 *
 * @param args String[] argv
 */
public static void
main(String[] args)
{
	LOGGER.info("Hello, world!");
}

}
