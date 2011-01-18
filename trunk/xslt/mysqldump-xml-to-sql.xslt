<?xml version="1.0"?>
<!--
    Copyright Roland Bouman
    Roland.Bouman@gmail.com
    http://rpbouman.blogspot.com/
    
    mysqldump-xml-to-sql.xsl is an XSLT Stylesheet to render mysqldump 
    XML output (obtained with mysqldump -X) as plain SQL text which can be 
    used to restore the database.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/

-->
<xsl:stylesheet 
    version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
>

<xsl:variable name="YES" select="'Y'"/>
<xsl:variable name="NO" select="'N'"/>

<xsl:variable name="TRANSACTION_LEVEL_DUMP" select="'dump'"/>
<xsl:variable name="TRANSACTION_LEVEL_DATABASE" select="'database'"/>
<xsl:variable name="TRANSACTION_LEVEL_TABLE" select="'table'"/>
<xsl:variable name="TRANSACTION_LEVEL_ROW" select="'row'"/>

<xsl:param name="max-allowed-packet" select="'@old_max_allowed_packet'"/>
<xsl:param name="identifier-quote" select="'`'"/>
<xsl:param name="identifier-quote-start" select="$identifier-quote"/>
<xsl:param name="identifier-quote-end" select="$identifier-quote"/>
<xsl:param name="schema" select="$YES"/>
<xsl:param name="data" select="$YES"/>
<xsl:param name="drop-database" select="$NO"/>
<xsl:param name="create-database" select="$YES"/>
<xsl:param name="drop-table" select="$NO"/>
<xsl:param name="single-inserts" select="$NO"/>
<xsl:param name="transaction-level" select="$TRANSACTION_LEVEL_TABLE"/>

<xsl:param name="flag-schema" select="$schema=$YES"/>
<xsl:param name="flag-data" select="$data=$YES"/>
<xsl:param name="flag-create-database" select="$create-database=$YES"/>
<xsl:param name="flag-drop-database" select="$drop-database=$YES"/>
<xsl:param name="flag-drop-table" select="$drop-table=$YES"/>
<xsl:param name="flag-single-inserts" select="$single-inserts=$YES"/>

<xsl:output
	method="text"
	encoding="ISO-8859-1"
/>

<xsl:variable name="START_TRANSACTION">
START TRANSACTION;
</xsl:variable>

<xsl:variable name="COMMIT">
COMMIT;
</xsl:variable>

<xsl:template name="quote-identifier">
    <xsl:param name="identifier"/>
<xsl:value-of select="concat($identifier-quote-start, $identifier, $identifier-quote-end)"/>    
</xsl:template>

<xsl:template match="/">
    <xsl:apply-templates/>
</xsl:template>

<xsl:template match="/mysqldump">
SET @old_max_allowed_packet := @@max_allowed_packet;

SET @@global.max_allowed_packet := <xsl:value-of select="$max-allowed-packet"/>;
<xsl:if test="$transaction-level = $TRANSACTION_LEVEL_DUMP"><xsl:value-of select="$START_TRANSACTION"/></xsl:if>
    <xsl:apply-templates/>
<xsl:if test="$transaction-level = $TRANSACTION_LEVEL_DUMP"><xsl:value-of select="$COMMIT"/></xsl:if>    

SET @@global.max_allowed_packet := @old_max_allowed_packet;
</xsl:template>

<xsl:template match="database">
<xsl:if test="$flag-schema">
<xsl:if test="$flag-drop-database">
DROP DATABASE <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@name"/></xsl:call-template>;
</xsl:if>
<xsl:if test="$flag-create-database">
CREATE DATABASE <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@name"/></xsl:call-template>;
</xsl:if>
</xsl:if>
<xsl:if test="count(../database)!=1 or $flag-create-database">
USE <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@name"/></xsl:call-template>
</xsl:if>
<xsl:if test="$flag-schema">
    <xsl:apply-templates select="table_structure[options[@Engine]]"/>
    <xsl:apply-templates select="table_structure[options[count(@Engine)=0 and @Comment='VIEW']]"/>
</xsl:if>
<xsl:if test="$flag-data">
<xsl:if test="$transaction-level = $TRANSACTION_LEVEL_DATABASE"><xsl:value-of select="$START_TRANSACTION"/></xsl:if>
    <xsl:apply-templates select="table_data[row]"/>
    <xsl:apply-templates select="table[row]"/>
<xsl:if test="$transaction-level = $TRANSACTION_LEVEL_DATABASE"><xsl:value-of select="$COMMIT"/></xsl:if>    
</xsl:if>
</xsl:template>

<xsl:template match="table_structure[options[@Engine]]">
<xsl:if test="$flag-drop-table">
DROP TABLE <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@name"/></xsl:call-template>;
</xsl:if>
CREATE TABLE <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@name"/></xsl:call-template> (
<xsl:apply-templates select="field"/>
<xsl:apply-templates select="key[@Seq_in_index='1']"/>
)
<xsl:apply-templates select="options"/>;
</xsl:template>

<xsl:template match="key[@Seq_in_index='1']">
<xsl:variable name="key-name" select="@Key_name"/>
,   <xsl:if test="$key-name!='PRIMARY'">
    <xsl:choose>
        <xsl:when test="@Non_unique='0'">CONSTRAINT</xsl:when>
        <xsl:when test="@Non_unique='1'"><xsl:if 
                test="
                    @Index_type='FULLTEXT'
                or  @Index_type='SPATIAL'
                "
            ><xsl:value-of select="@Index_type"/><xsl:text> </xsl:text></xsl:if>INDEX</xsl:when>
    </xsl:choose><xsl:text> </xsl:text><xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="$key-name"/></xsl:call-template>    
</xsl:if>
<xsl:if test="@Non_unique='0'">    
    <xsl:choose>
        <xsl:when test="$key-name='PRIMARY'">PRIMARY KEY</xsl:when>
        <xsl:otherwise> UNIQUE</xsl:otherwise>
    </xsl:choose>
</xsl:if> (
        <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@Column_name"/></xsl:call-template>
        <xsl:if test="@Sub_part!=''">(<xsl:value-of select="@Sub_part"/>)</xsl:if>
        <xsl:apply-templates select="../key[@Key_name=$key-name and @Seq_in_index!='1']"/>
    )<xsl:if 
        test="
            @Index_type = 'BTREE'
        or  @Index_type = 'HASH'
        "
    > USING <xsl:value-of select="@Index_type"/></xsl:if></xsl:template>

<xsl:template match="key[@Seq_in_index!='1']">
    ,   <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@Column_name"/></xsl:call-template>
    <xsl:if test="@Sub_part!=''">(<xsl:value-of select="@Sub_part"/>)</xsl:if>
</xsl:template>
<xsl:template match="options">ENGINE = <xsl:value-of select="@Engine"/>
<xsl:if test="@Comment!=''">COMMENT '<xsl:value-of select="@Comment"/>'</xsl:if>
</xsl:template>

<xsl:template match="table_structure[options[count(@Engine)=0 and @Comment='VIEW']]">
/* BUG: we can't create this view because the dump does not contain the view code. 
<xsl:if test="$flag-drop-table">
DROP VIEW <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@name"/></xsl:call-template>;
</xsl:if>
CREATE VIEW <xsl:call-template name="quote-identifier"><xsl:with-param name="identifier" select="@name"/></xsl:call-template> (
<xsl:apply-templates select="field"/>
);
*/
</xsl:template>

<xsl:template match="table_structure/field">
<xsl:choose>
    <xsl:when test="position()&gt;1">
,   </xsl:when>
    <xsl:otherwise><xsl:text>    </xsl:text></xsl:otherwise>
</xsl:choose><xsl:call-template name="quote-identifier">
    <xsl:with-param name="identifier" select="@Field"/>
</xsl:call-template><xsl:if test="../options[@Engine]"> 
    <xsl:text> </xsl:text><xsl:value-of select="@Type"/>
    <xsl:if test="@Null='NO'"> NOT NULL</xsl:if>
    <xsl:if test="@Default"> DEFAULT <xsl:call-template name="default"><xsl:with-param name="field" select="."/></xsl:call-template></xsl:if>
    <xsl:if test="@Extra"><xsl:text> </xsl:text><xsl:value-of select="@Extra"/></xsl:if>
</xsl:if>
</xsl:template>

<xsl:template name="datatype-needs-quotes">
    <xsl:param name="type"/>
    <xsl:choose>
        <xsl:when 
            test="
                starts-with($type, 'bigint')
            or  starts-with($type, 'bit')
            or  starts-with($type, 'blob')
            or  starts-with($type, 'decimal')
            or  starts-with($type, 'double')
            or  starts-with($type, 'float')
            or  starts-with($type, 'longblob')
            or  starts-with($type, 'mediumblob')
            or  starts-with($type, 'mediumint')
            or  starts-with($type, 'int')
            or  starts-with($type, 'smallint')
            or  starts-with($type, 'tinyblob')
            or  starts-with($type, 'tinyint')
            or  starts-with($type, 'year')
            "
        >0</xsl:when>
        <xsl:when
            test="
                starts-with($type, 'binary')
            or  starts-with($type, 'char')
            or  starts-with($type, 'date')
            or  starts-with($type, 'datetime')
            or  starts-with($type, 'enum')
            or  starts-with($type, 'longtext')
            or  starts-with($type, 'mediumtext')
            or  starts-with($type, 'set')
            or  starts-with($type, 'text')
            or  starts-with($type, 'time')
            or  starts-with($type, 'tinytext')
            or  starts-with($type, 'varbinary')
            or  starts-with($type, 'varchar')
            "
        >1</xsl:when>
        <xsl:otherwise>
            <xsl:message>
                Unexpected data type <xsl:value-of select="$type"/>.
            </xsl:message>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="default">
    <xsl:param name="field"/>
    <xsl:variable name="type" select="$field/@Type"/>
    <xsl:variable name="default" select="$field/@Default"/>    
    <xsl:choose>
        <xsl:when test="starts-with($type, 'timestamp')">
            <xsl:choose>
                <xsl:when test="$default='CURRENT_TIMESTAMP'">CURRENT_TIMESTAMP</xsl:when>
                <xsl:otherwise>'<xsl:value-of select="$default"/>'</xsl:otherwise>
            </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
            <xsl:variable name="datatype-needs-quotes">
                <xsl:call-template name="datatype-needs-quotes">
                    <xsl:with-param name="type" select="$type"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:choose>
                <xsl:when test="$datatype-needs-quotes='1'">'<xsl:call-template name="escape-quotes">
                    <xsl:with-param name="value" select="$default"/>
                </xsl:call-template>'</xsl:when>
                <xsl:otherwise><xsl:value-of select="$default"/></xsl:otherwise>
            </xsl:choose>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<!--

    Added this to cope with "steve"'s dump format, see: 
    http://rpbouman.blogspot.com/2010/04/restoring-xml-formatted-mysql-dumps.html?showComment=1295382737293#c8998217029331514581

    For referernce, this is the structure:
    
    <mysqldump>
    <database name="mediaDb" schemaVer="1.4.2">
        <table name="advisoryTable">
        </table>
        <table name="aggregateTable">
            <row>
                <field name="aggregateMID">737</field>
                <field name="MID">17800</field>
                <field name="sequenceNum">1</field>
            </row>
            <row>
                <field name="aggregateMID">737</field>
                <field name="MID">15850</field>
                <field name="sequenceNum">2</field>
            </row>
            <row>
                <field name="aggregateMID">737</field>
                <field name="MID">15858</field>
                <field name="sequenceNum">3</field>
            </row>
        </table>
    </database>
    </mysqldump>
    
-->
<xsl:template match="table[row]">
    <xsl:variable name="name" select="@name"/>
    <xsl:variable name="quoted-table-name">
        <xsl:call-template name="quote-identifier">
            <xsl:with-param name="identifier" select="$name"/>
        </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="row-fields" select="row[1]/field"/>
    <xsl:variable name="column-name-list">(<xsl:for-each select="$row-fields">
            <xsl:if test="position()!=1">, </xsl:if>
            <xsl:call-template name="quote-identifier">
                <xsl:with-param name="identifier" select="@name"/>
            </xsl:call-template>
        </xsl:for-each>)</xsl:variable>
    <xsl:variable name="rows" select="row"/>
    <xsl:variable name="quote-field-flags">
        <xsl:for-each select="$row-fields">
            <xsl:variable name="field-name" select="@name"/>
            <xsl:choose>
                <xsl:when test="$rows[field[@name=$field-name and text()!='' and string(number(text()))='NaN']]">1</xsl:when>
                <xsl:otherwise>0</xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:variable>
<xsl:for-each select="row">
    <xsl:call-template name="row">
        <xsl:with-param name="row" select="."/>
        <xsl:with-param name="quoted-table-name" select="$quoted-table-name"/>
        <xsl:with-param name="column-name-list" select="$column-name-list"/>
        <xsl:with-param name="quote-field-flags" select="$quote-field-flags"/>
    </xsl:call-template>
</xsl:for-each>
</xsl:template>

<xsl:template match="table_data[row]">
    <xsl:variable name="name" select="@name"/>
    <xsl:variable name="quoted-table-name">
        <xsl:call-template name="quote-identifier">
            <xsl:with-param name="identifier" select="$name"/>
        </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="table-structure" select="../table_structure[@name=$name]"/>
    <xsl:variable name="row-fields" select="row[1]/field"/>
    <xsl:variable name="quote-field-flags">
        <xsl:for-each select="$row-fields">
            <xsl:variable name="field-name" select="@name"/>
            <xsl:choose>
                <xsl:when test="@xsi:type='xs:hexBinary'">2</xsl:when>
                <xsl:otherwise>                    
                    <xsl:call-template name="datatype-needs-quotes">
                        <xsl:with-param name="type" select="$table-structure/field[@Field=$field-name]/@Type"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="column-name-list">(<xsl:for-each select="$row-fields">
            <xsl:if test="position()!=1">, </xsl:if>
            <xsl:call-template name="quote-identifier">
                <xsl:with-param name="identifier" select="@name"/>
            </xsl:call-template>
        </xsl:for-each>)</xsl:variable>
<xsl:if test="$transaction-level = $TRANSACTION_LEVEL_TABLE">
<xsl:value-of select="$START_TRANSACTION"/>
</xsl:if>
    <xsl:if test="not($table-structure)">
        <xsl:message>
            Warning! This dump does not contain the structure for the table 
            <xsl:call-template name="quote-identifier">
                <xsl:with-param name="identifier" select="$table-data/../@name"/>
            </xsl:call-template>.<xsl:value-of select="$quoted-table-name"/>
            SQL will be generated, but you may not be able to execute it...
        </xsl:message>
    </xsl:if>
<xsl:for-each select="row">
    <xsl:call-template name="row">
        <xsl:with-param name="row" select="."/>
        <xsl:with-param name="quoted-table-name" select="$quoted-table-name"/>
        <xsl:with-param name="column-name-list" select="$column-name-list"/>
        <xsl:with-param name="quote-field-flags" select="$quote-field-flags"/>
    </xsl:call-template>
</xsl:for-each>
<xsl:if test="$transaction-level = $TRANSACTION_LEVEL_TABLE"><xsl:value-of select="$COMMIT"/>
</xsl:if>
</xsl:template>

<xsl:variable name="apos">&apos;</xsl:variable>
<xsl:template name="escape-quotes">
    <xsl:param name="value"/>
    <xsl:choose>
        <xsl:when test="contains($value, $apos)">
            <xsl:call-template name="escape-quotes">
                <xsl:with-param name="value" 
                    select="
                        concat(
                            substring-before($value, $apos)
                        ,   $apos
                        ,   substring-after($value, $apos)
                        )
                    "
                />
            </xsl:call-template>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$value"/></xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="row">
    <xsl:param name="row"/>
    <xsl:param name="quoted-table-name"/>
    <xsl:param name="column-name-list"/>
    <xsl:param name="quote-field-flags"/>
    
    <xsl:if test="$flag-single-inserts or position()=1">
INSERT INTO <xsl:value-of select="$quoted-table-name"/><xsl:text> </xsl:text><xsl:value-of select="$column-name-list"/><xsl:text> </xsl:text>VALUES<xsl:text> </xsl:text></xsl:if>
<xsl:if test="position()!=1 and not($flag-single-inserts)">,</xsl:if>
(<xsl:for-each select="field">
            <xsl:variable name="flag" select="substring($quote-field-flags,position(),1)"/>
            <xsl:if test="position()!=1">, </xsl:if>
            <xsl:choose>
                <xsl:when test="@xsi:nil='true'">NULL</xsl:when>
                <xsl:when test="$flag='1'">'<xsl:call-template name="escape-quotes"><xsl:with-param name="value" select="text()"/></xsl:call-template>'</xsl:when>
                <xsl:otherwise><xsl:if test="$flag='2'">0x</xsl:if><xsl:value-of select="text()"/></xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>)<xsl:if test="$flag-single-inserts or position()=last()">;</xsl:if>
</xsl:template>

</xsl:stylesheet>