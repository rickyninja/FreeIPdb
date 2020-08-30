-- #                _____              ___ ____     _ _
-- #               |  ___| __ ___  ___|_ _|  _ \ __| | |__
-- #               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
-- #               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
-- #               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
-- #
-- #	Data_Types.txt-$Name:  $-$Revision: 1.4 $ $Date: 2003/05/11 21:48:46 $ <$Author: bapril $@freeipdb.org>
-- #####################################################################;


CREATE TABLE REGIONTABLE (
	ID       SERIAL,
	NAME     VARCHAR(20) UNIQUE NOT NULL,
	DESCR    VARCHAR(30),
	PARENT   INT,
	V6       BOOL,
	COUNTRY	 VARCHAR(6),
	HOLDTIME INT
);

GRANT ALL ON REGIONTABLE TO freeipdb;
GRANT ALL ON REGIONTABLE_ID_SEQ TO freeipdb;

CREATE TABLE LOCKTABLE (
	OWNER	VARCHAR(30),
	SETTIME	INT
);
GRANT ALL ON LOCKTABLE TO freeipdb;

CREATE TABLE IPDB (
	ID		SERIAL,
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

GRANT ALL ON IPDB to freeipdb;
GRANT ALL ON IPDB_ID_SEQ to freeipdb;
