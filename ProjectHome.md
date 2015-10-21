For some background of this project, read my blog:
http://rpbouman.blogspot.com/2010/04/restoring-xml-formatted-mysql-dumps.html

MySQL logical backups are often created with mysqldump (http://dev.mysql.com/doc/refman/5.1/en/mysqldump.html). Normall y this is used to export data and structure in the form of SQL DML and DDL statements respectively. There is also an option to output to XML format (using the -X option on the mysqldump command line).

MySQL does not currently provide any method to restore from XML dumps. This is a problem for those uses that are unaware of this option that need to restore their XML backups. This project provides an XSLT stylesheet to convert XML backups created with the mysqldump -X option back to an SQL script (DDL, DML, or both).

This is an example command line that dumps the sakila database to XML:

mysqldump -uroot -pmysql -P3351 -X --hex-blob --create-options --databases sakila > sakila.xml

(note that the --hex-blob option is required - the -X option does not automatically escape BLOB data)

To restore sakila.xml, you can generate an SQL script with:

xsltproc mysqldump-xml-to-sql.xslt sakila.xml > sakila.sql

sakila.sql can be restored in the usual way with the mysql command line client. (You can probably also pipeline it, but I haven't tested that yet)
