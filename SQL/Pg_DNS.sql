-- #                _____              ___ ____     _ _
-- #               |  ___| __ ___  ___|_ _|  _ \ __| | |__
-- #               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
-- #               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
-- #               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
-- #
-- #	DNS.sql-$Name:  $-$Revision: 1.1 $ $Date: 2003/11/07 12:23:59 $ <$Author: ben $@freeipdb.org>
-- #####################################################################;

-- ZONE                    
--        A               The Fwd Domain
--        CNAME           The Fwd Domain
--        NS              The Zone (Fwd or Reverse)
--        MX              The Fwd Domain
--        DELEGATE        The Zone (Fwd or Reverse)
--        PTR             The Fwd Domain
-- Block
--        A               The Block for the ip-address
--        CNAME           (Null)
--        NS              (Null)
--        MX              (Null)
--        Delegate        (Null)
--        PTR             The Block for the ip-address

-- Hostname 
--        A               The Host portion of the name
--        CNAME           The FQDN of the primary name
--        NS              The FQDN A Record of the NS
--        MX              The FQDN A Record of the MX
--        Delegate        The FQDN A Record of the NS
--        PTR             The Host portion of the name

-- Text
--        A               (Null)
--        CNAME           The Fwd Name
--        NS              The Fwd Name (also @ in rev delgation)
--        MX              The Fwd Name (or blank)               
--        Delegate        (Null)
--        PTR             (Null)
-- Index
--        A               The IP within [Block]
--        CNAME           (Null)
--        NS              Number of IP's in block.
--        MX              Precedence
--        Delegate        Number of IP's in block.
--        PTR             The IP within [Block]

-- IP
--	A		If the block is not IN FreeIPdb
--	CNAME		(Null)
--	NS		(Null)
--	MX		(Null)
--	Delegate	(Null)
--	PTR		(Null)


CREATE TABLE zone_record_table (
	ID		SERIAL,
	ZONE		INT NOT NULL,
	TYPE		INT NOT NULL,
	BLOCK		INT,
	IDEX		INT,		-- Had to change to be compatible with Mysql
	HOSTNAME	VARCHAR(256),
	TEXT		VARCHAR(256),
	IP		NUMERIC(40,0)
);
GRANT ALL ON zone_record_table TO freeipdb;
GRANT ALL ON zone_record_table_id_seq TO freeipdb;

-- 1 = A
-- 2 = PTR
-- 3 = CNAME
-- 4 = NS
-- 5 = MX
-- 6 = Delegate whole block.

CREATE TABLE ZONE_TABLE (
	ID		SERIAL,
	NAME		VARCHAR(256) NOT NULL,
	PARENT		INT NOT NULL,
	OWN		BOOL,
	REVERSE_BLOCK	INT,
	SERIAL		INT, 
	RETRY		INT, 
	REFRESH		INT,
	EXPIRE		INT,
	TTL		INT
);
GRANT ALL ON ZONE_TABLE TO freeipdb;
GRANT ALL ON ZONE_TABLE_ID_SEQ TO freeipdb;

INSERT INTO ZONE_TABLE (NAME,PARENT,OWN) VALUES ('.',0,'f');
INSERT INTO ZONE_TABLE (NAME,PARENT,OWN) VALUES ('net',1,'f');
INSERT INTO ZONE_TABLE (NAME,PARENT,OWN) VALUES ('com',1,'f');
INSERT INTO ZONE_TABLE (NAME,PARENT,OWN) VALUES ('org',1,'f');
INSERT INTO ZONE_TABLE (NAME,PARENT,OWN) VALUES ('arpa',1,'f');
INSERT INTO ZONE_TABLE (NAME,PARENT,OWN) VALUES ('in-addr',8,'f');
