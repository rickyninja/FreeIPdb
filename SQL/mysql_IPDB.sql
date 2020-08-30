-- #                _____              ___ ____     _ _
-- #               |  ___| __ ___  ___|_ _|  _ \ __| | |__
-- #               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
-- #               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
-- #               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
-- #
-- #	Data_Types.txt-$Name:  $-$Revision: 1.4 $ $Date: 2003/05/11 21:48:46 $ <$Author: bapril $@freeipdb.org>
-- #####################################################################;

CREATE DATABASE freeipdb;
\u freeipdb

CREATE TABLE REGIONTABLE (
	ID       INTEGER AUTO_INCREMENT PRIMARY KEY, 
	NAME     VARCHAR (20) NOT NULL UNIQUE,
	DESCR    VARCHAR(30),
	PARENT   INTEGER,
	V6       BOOL,
	COUNTRY  VARCHAR(6),
	HOLDTIME INTEGER
);

GRANT ALL PRIVILEGES ON REGIONTABLE.* TO freeipdb@"%" identified by 'freeipdb' ;
GRANT ALL PRIVILEGES ON REGIONTABLE_ID_SEQ.* TO freeipdb@"%" identified by 'freeipdb';

CREATE TABLE LOCKTABLE (
	OWNER	VARCHAR(30),
	SETTIME	INT
);
GRANT ALL PRIVILEGES ON LOCKTABLE TO freeipdb@"%" identified by 'freeipdb';

CREATE TABLE IPDB (
	ID		INTEGER AUTO_INCREMENT PRIMARY KEY,
	BLOCK		NUMERIC(40,0) NOT NULL,
	BITS		INT NOT NULL,
	REGION		INT NOT NULL,
	PARENT		INT NOT NULL,
	CHILDL		INT,
	CHILDR		INT,
	ALLOCATED	INT,
	CUSTNUM		INT,
	CUSTDESC	VARCHAR(60),
	RECLAIM		INT,
	PRIORITY	INT,
	HOLDTIME	INT
);

GRANT ALL PRIVILEGES ON IPDB to freeipdb@"%" identified by 'freeipdb';
GRANT ALL PRIVILEGES ON IPDB_ID_SEQ to freeipdb@"%" identified by 'freeipdb';
