package org.evolvis.tartools.mvnparent;

/*-
 * Copyright © 2016, 2018, 2019, 2020
 *	mirabilos (t.glaser@qvest-digital.com)
 * Licensor: Qvest Digital AG, Bonn
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

import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.logging.Logger;

import static net.trajano.commons.testing.UtilityClassTestUtil.assertUtilityClassWellDefined;
import static org.junit.jupiter.api.Assertions.*;

class InitialiseLoggingTest {

public static final String TESTFILE_CLASSPATH = "simplelogger.properties";
public static final String TESTFILE_LOCALPATH = "../src/test/resources/" +
    TESTFILE_CLASSPATH;

@Test
public void
testUtilityClass() throws ReflectiveOperationException
{
	assertUtilityClassWellDefined(InitialiseLogging.class);
}

private static byte[]
bytesFrominputStream(final InputStream is) throws IOException
{
	try (final ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
		final byte[] buf = new byte[512];
		int n;

		while ((n = is.read(buf)) != -1)
			baos.write(buf, 0, n);
		return baos.toByteArray();
	}
}

@Test
public void
testPos() throws IOException
{
	assertNull(InitialiseLogging.LOGGER, "LOGGER was not initialised yet");
	InitialiseLogging.InitialiseJDK14Logging();
	assertNotNull(InitialiseLogging.LOGGER, "LOGGER could not be initialised");
	Logger.getLogger(InitialiseLoggingTest.class.getName()).info("meow");

	InputStream ls = InitialiseLogging.getResourceAsStream("miau");
	byte[] lb = bytesFrominputStream(ls);
	byte[] tb = new byte[] {
	    (byte)0xF0, (byte)0x9F, (byte)0x90, (byte)0x88, (byte)0x0A
	};
	assertArrayEquals(tb, lb, "cannot load a binary local file");

	ls = InitialiseLogging.getResourceAsStream(TESTFILE_CLASSPATH);
	lb = bytesFrominputStream(ls);
	tb = Files.readAllBytes(Paths.get(TESTFILE_LOCALPATH));
	assertArrayEquals(tb, lb, "cannot load a properties file from classpath");

	ls = InitialiseLogging.getResourceAsStream("META-INF/Messages.properties");
	String lS = new String(bytesFrominputStream(ls), StandardCharsets.ISO_8859_1);
	assertTrue(lS.contains("UtilityClassTestUtil"), "cannot load lib properties");
}

}
