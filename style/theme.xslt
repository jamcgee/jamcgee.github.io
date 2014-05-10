<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="xsl xhtml"
    version="1.0">
  <xsl:output
      method="xml" encoding="utf-8" indent="no"
      omit-xml-declaration="yes"
      doctype-system="about:legacy-compat"
      media-type="application/xhtml+xml" />
  <xsl:strip-space elements="*"/>
  <xsl:preserve-space elements="xhtml:pre"/>
  <xsl:param name="documentUri"/>

  <!-- Copy Nodes Verbatim by default -->
  <xsl:template match="@*|node()">
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
  </xsl:template>

  <!-- Insert additional metadata into the header -->
  <xsl:template match="xhtml:head">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <meta charset="utf-8"/>
      <xsl:apply-templates select="node()"/>
      <link rel="stylesheet" href="/style/theme.css"/>
      <meta name="viewport" content="width=device-width, user-scalable=no"/>
    </xsl:copy>
  </xsl:template>

  <!-- Helper template to render a link in the navbar -->
  <xsl:template name="navlink">
    <xsl:param name="href"/>
    <xsl:param name="text"/>
    <xsl:param name="exact" select="false()"/>
    <li><a>
      <xsl:attribute name="href"><xsl:value-of select="$href"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="$documentUri=$exact">
          <xsl:attribute name="class">active</xsl:attribute>
        </xsl:when>
        <xsl:when test="not($exact) and starts-with($documentUri, $href)">
          <xsl:attribute name="class">active</xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <xsl:value-of select="$text"/>
    </a></li>
  </xsl:template>

  <!-- Wrap the body text with the actual styling, add nav, etc. -->
  <xsl:template match="xhtml:body">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <ul class="navbar" id="top">
        <xsl:call-template name="navlink">
          <xsl:with-param name="href" select="'/'"/>
          <xsl:with-param name="text" select="'Home'"/>
          <xsl:with-param name="exact" select="'/index.xhtml'"/>
        </xsl:call-template>
        <xsl:call-template name="navlink">
          <xsl:with-param name="href" select="'/resume/'"/>
          <xsl:with-param name="text" select="'Resume'"/>
        </xsl:call-template>
      </ul>
      <xsl:choose>
        <xsl:when test="*[@class='banner']">
          <!-- Copy Banner -->
          <xsl:apply-templates select="*[@class='banner']"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- Synthesize Banner -->
          <div class="banner">
            <h1><xsl:apply-templates select="/xhtml:html/xhtml:head/xhtml:title/node()"/></h1>
          </div>
        </xsl:otherwise>
      </xsl:choose>
      <div class="content">
        <xsl:apply-templates select="*[count(@class)=0 or @class!='banner']"/>
      </div>
      <div class="copyright">Copyright © 2014 Jonathan McGee</div>
      <div class="hidden">Send spam to <a href="mailto:spamtrap@etherealwake.com">spamtrap@etherealwake.com</a></div>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
