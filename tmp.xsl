<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY nl "&#x0A;">
]>
<!-- https://stackoverflow.com/a/4747858/2171120 -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output method="text" encoding="UTF-8" indent="no"/>
	<xsl:strip-space elements="*"/>
	<xsl:variable name="sq">'</xsl:variable>
	<xsl:template name="quote">
		<xsl:value-of select="concat($sq, ., $sq)"/>
	</xsl:template>
	<xsl:template match="*[@* or not(*)]">
		<xsl:if test="not(*)">
			<xsl:apply-templates select="ancestor-or-self::*" mode="path"/>
			<xsl:text>=</xsl:text>
			<xsl:call-template name="quote"/>
			<xsl:text>&nl;</xsl:text>
		</xsl:if>
		<xsl:apply-templates select="@*|*"/>
	</xsl:template>
	<xsl:template match="*" mode="path">
		<xsl:value-of select="concat('/', name())"/>
		<xsl:variable name="precSiblings" select="count(preceding-sibling::*[name()=name(current())])"/>
		<xsl:variable name="nextSiblings" select="count(following-sibling::*[name()=name(current())])"/>
		<xsl:if test="$precSiblings or $nextSiblings">
			<xsl:value-of select="concat('[', $precSiblings + 1, ']')"/>
		</xsl:if>
	</xsl:template>
	<xsl:template match="@*">
		<xsl:apply-templates select="../ancestor-or-self::*" mode="path"/>
		<xsl:text>[@</xsl:text>
		<xsl:value-of select="name()"/>
		<xsl:text>=</xsl:text>
		<xsl:call-template name="quote"/>
		<xsl:text>]&nl;</xsl:text>
	</xsl:template>
</xsl:stylesheet>
