package org.evolvis.tartools.mvnparent;

/*-
 * Copyright © 2016, 2018, 2019, 2020
 *      mirabilos (t.glaser@tarent.de)
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

import java.io.IOException;
import java.io.InputStream;
import java.util.logging.Level;
import java.util.logging.LogManager;
import java.util.logging.Logger;

/**
 * Utility class with helper functions to load a file from the classpath
 * and initialise JDK14 “jul” ({@link java.util.logging}) logging
 *
 * @author mirabilos (t.glaser@tarent.de)
 */
public final class InitialiseLogging {

private static final String EINIT = "could not initialise logging subsystem";
private static final String ENOTFOUND = "configuration file %s not found";
private static final String LOGCFG = "logging.properties";
private static boolean LOG14INITED = false;
static Logger LOGGER;

/**
 * Prevent instantiation (this is a utility class with only static methods)
 */
private InitialiseLogging()
{
}

public static InputStream
getResourceAsStream(final String filename)
{
	return Thread.currentThread().getContextClassLoader().getResourceAsStream(filename);
}

public static void
InitialiseJDK14Logging()
{
	if (LOG14INITED)
		return;

	final InputStream config = getResourceAsStream(LOGCFG);
	IOException exception = null;

	if (config == null) {
		exception = new IOException(String.format(ENOTFOUND, LOGCFG));
	} else {
		try {
			LogManager.getLogManager().readConfiguration(config);
			LOG14INITED = true;
		} catch (IOException e) {
			exception = e;
		}
	}

	LOGGER = Logger.getLogger(InitialiseLogging.class.getName());
	if (exception != null) {
		LOGGER.log(Level.SEVERE, EINIT, exception);
	}
}

}
