<xsl:stylesheet version="2.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:sf="http://soap.sforce.com/2006/04/metadata">
	<xsl:output omit-xml-declaration="yes" indent="yes"/>

	<!-- 	<xsl:output method="spring:beans" doctype-system="http://www.springframework.org/dtd/spring-beans.dtd" doctype-public="-//SPRING//DTD BEAN//EN" indent="yes" /> -->

	<xsl:param name="csv"/>
	<xsl:param name="logdir"/>
	<xsl:param name="operation"/>
	<xsl:param name="endpoint"/>
	<xsl:param name="mappingfile"/>
	<xsl:param name="entity"/>
	<xsl:param name="soql"/>
	<xsl:param name="password"/>
	<xsl:param name="username"/>
	<xsl:param name="dataaccess"/>
	<xsl:param name="bulkapi"/>
	<xsl:param name="batchsize"/>
	<xsl:param name="externalid"/>
	

	<xsl:template match="node()|@*">
		<xsl:copy>
			<xsl:apply-templates select="node()|@*"/>
		</xsl:copy>
	</xsl:template>

	<!-- <xsl:template match="@value[parent::entry[@key='sfdc.extractionRequestSize']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$batchsize"/>
		</xsl:attribute>
	</xsl:template> -->
	
	<xsl:template match="@value[parent::entry[@key='sfdc.loadBatchSize']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$batchsize"/>
		</xsl:attribute>
	</xsl:template>
	
	<xsl:template match="@value[parent::entry[@key='sfdc.externalIdField']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$externalid"/>
		</xsl:attribute>
	</xsl:template>
	
	<xsl:template match="@value[parent::entry[@key='dataAccess.name']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$csv"/>
		</xsl:attribute>
	</xsl:template>
	
	<xsl:template match="@value[parent::entry[@key='sfdc.useBulkApi']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$bulkapi"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='process.operation']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$operation"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='process.mappingFile']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$mappingfile"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='dataAccess.type']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$dataaccess"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='process.lastRunOutputDirectory']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$logdir"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='process.statusOutputDirectory']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$logdir"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='sfdc.endpoint']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$endpoint"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='sfdc.entity']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$entity"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='sfdc.extractionSOQL']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$soql"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='sfdc.password']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$password"/>
		</xsl:attribute>
	</xsl:template>

	<xsl:template match="@value[parent::entry[@key='sfdc.username']]">
		<xsl:attribute name="value">
			<xsl:value-of select="$username"/>
		</xsl:attribute>
	</xsl:template>

</xsl:stylesheet>