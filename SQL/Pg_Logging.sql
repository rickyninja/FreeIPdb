-- #                _____              ___ ____     _ _
-- #               |  ___| __ ___  ___|_ _|  _ \ __| | |__
-- #               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
-- #               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
-- #               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
-- #
-- #    Logging.sql-$Name:  $-$Revision: 1.1 $ $Date: 2003/11/07 12:23:59 $ <$Author: ben $@freeipdb.org>
-- #####################################################################;

-- Log table

CREATE TABLE LOG_TABLE (
	TIME		INT,
	REMOTE_USER	VARCHAR(30), -- Make longer if needed.
	REMOTE_ADDR	VARCHAR(30), -- Make longer if needed.
	CODE		INT,
--				1  + Add RA
--				2  + Delete RA 
--				3  + Add Region
--				4  + Delete Region
--				5  + Add Supernet
--				6  - Move block (to region)
--				7  - Set Priotiry
--				8  + Set Reclaim
--				9  - Allocate block (specified)
--				10 + Allocate Block (auto)
--				11 + Reclaim Block
--				12 + Clear Holdtime
--				14 - Edit CUSTNUM
--				15 - Edit CUSTDESC

--				20 - Enable DNS Zone
--				21 - Disable DNS Zone
--				22 - Create DNS Record
--				23 - Delete DNS Record
	REGION		INT,
	IP		NUMERIC(40,0),
	BLOCK		INT,
	BITS		INT,
	TEXT		VARCHAR(255),	-- Region name, RA name, CUSTDESC
	NUMBER		INT,		-- Priority, CUSTNUM

	DNS_record_type	INT,
	DNS_ZONE	INT,
	DNS_HOSTNAME	VARCHAR(256),
	DNS_TEXT	VARCHAR(256),
	DNS_IP		NUMERIC(40,0)
);

GRANT ALL ON LOG_TABLE TO freeipdb;
