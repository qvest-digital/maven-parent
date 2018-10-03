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
		<xsl:param name="str"/>
		<xsl:choose>
			<xsl:when test="contains($str, $sq)">
				<xsl:value-of select="substring-before($str, $sq)"/>
				<xsl:text>'\''</xsl:text>
				<xsl:call-template name="quote">
					<xsl:with-param name="str" select="substring-after($str, $sq)"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$str"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="renderEQvalue">
		<xsl:text>='</xsl:text>
		<xsl:call-template name="quote">
			<xsl:with-param name="str" select="."/>
		</xsl:call-template>
	</xsl:template>
	<xsl:template match="*[@* or not(*)]">
		<xsl:if test="not(*)">
			<xsl:text>/</xsl:text>
			<xsl:apply-templates select="ancestor-or-self::*" mode="path"/>
			<xsl:call-template name="renderEQvalue"/>
			<xsl:text>'&nl;</xsl:text>
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
		<xsl:text>/</xsl:text>
		<xsl:apply-templates select="../ancestor-or-self::*" mode="path"/>
		<xsl:text>[@</xsl:text>
		<xsl:value-of select="name()"/>
		<xsl:call-template name="renderEQvalue"/>
		<xsl:text>']&nl;</xsl:text>
	</xsl:template>
</xsl:stylesheet>
