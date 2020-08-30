#                _____              ___ ____     _ _
#               |  ___| __ ___  ___|_ _|  _ \ __| | |__
#               | |_ | '__/ _ \/ _ \| || |_) / _` | '_ \
#               |  _|| | |  __/  __/| ||  __/ (_| | |_) |
#               |_|  |_|  \___|\___|___|_|   \__,_|_.__/
#
#	README.TXT-$Name:  $-$Revision: 1.9 $ $Date: 2002/05/07 23:30:55 $ <$Author: bapril $@freeipdb.org>
######################################################################

1  What is FreeIPdb?
2  Features.
3  How does FreeIPdb Work?
4  What are the requirements to run FreeIPdb?
5  How do I get Help with FreeIPdb?
6  How do I drive FreeIPdb?

1		What is FreeIPdb.

2		Features

       Regions: A Region is used to divide or combine portions of 
       	IP space into a independent sections. This gives the 
	operator the ability to either keep IP space separate 
	(i.e. RIPE,APNIC,ARIN), Allocate a subnet to a project 
	or customer that would then be allowed to assign subnets 
	from that subnet in any manner they choose. (i.e. operator 
	allocates a /24 to the new "shiny-widget" project. The 
	manager of the "shiny-widget" project chooses to assign 
	a /25 to the "widgets" and a /26 to the "shiny things" in 
	L.A. and a /27 to the "shiny things" in New York. The 
	manager can see that he has a /27 left and the operator 
	knows exactly how the project manager used the IP space that
	he was assigned.) Two different regions are allowed to contain 
	IP space from the same block (i.e. more than one region of 
	RFC-1918 space).  
       Reclaim: When a block (or a parent of it) is in reclaim mode 
	that block will NOT be re-allocated or assigned from the 
	database in the event that it is reclaimed. This feature 
	is useful if the operator has a need to return a block of 
	IP space to a RIR or any situation where it is not desirable 
	for a block to be allocated or assigned. 
       Priorities: As supernets are added to the database for the 
	first time the operator may assign a priority. A priority 
	is a value that can be used by the database to assign/allocate 
	space from one supernet before another. 
       IPv6: FreeIPdb works seamlessly with IPv6. The only restriction 
	is that IPv6 space be added in a region that contains no IPv4 
	Space. Other than that all features work the same way. 
       Hold Time: The operator may set a global hold time (this will 
       	soon be per region). Every time a block is reclaimed a 
	datestamp is set in the block (current time + holdime) when 
	that datestamp is less then the current time the database 
	will once again allow that block to be allocated/assigned or 
	rolled up into it's parent. 
       Set a specific block: In the event the operator needs to 
	allocate/assign an exact block (i.e. not whatever the database 
	returns) they can use the "Set a specific block" feature. The 
	database will automaticly create all the parents and children 
	needed to locate this block in the database. 

3               How does FreeIPdb work?

       FreeIPdb is based on a binary tree database. Every block can 
       be the parent of 2 children (A /24 is the parent of 2 /25's). 
       FreeIPdb is written in Perl to be universally portable. 
       All IP addresses (v4 and v6) are stored in the database as integers 
       The allocation and reclaim routines are fully recursive. 
       If both children of a parent are not in use both children 
       will be pruned from the tree and the parent
       etc... 
       The database uses an algorithm of best fit. If you do nothing 
       but assignment/allocation(s) you will never have more than 
       one unused block of each size in that given region at any time. 



4               What are the requirements to run FreeIPdb?
       A Perl interpreter. (tested on 5.005_03 built for i386-freebsd). 
       PostgreSQL 7.0 with Perl interface installed. (also tested on 7.1.2). 
       Math::BigInt-1.42 We're dealing with some mind-boggling-ly big numbers. 
       Net::IP-1.0 
       A Webserver capable of running Perl cgi (If you want the web front-end.) 
       Net::Telnet (for the route announcment check).


5               How do I get Help with FreeIPdb

       Send an e-mail to the addresses below with 'subscribe' in the subject 
       (you should know how to do this by now;-) 
       Announce - announce-request@FreeIPdb.org - 
       		New releases and important updates. 
       Users - users-request@FreeIPdb.org - 
       		User questions and support. 
       Hackers - hackers-request@FreeIPdb.org - 
       		Development and customization.

6  		How do I drive FreeIPdb?
	
	I'm glad you asked that! Lets start with the admin.cgi page.
	It should be something like cgi-bin/freeipdb-?_?_?/admin.cgi.
	This is where you will add new Registrars, Regions, and Allocations.
	The first thing we need is a Registrar(RA). We'll use ARIN for our
	example. You could use RIPE,APNIC,My_RAR,RFC1918 whatever you want.
	A RA is used to keep track of which space comes from which Authority.
	This way when it comes time to go get more we can do some easy reports
	and poof you're done. So find the section titled "Add a RA", fill in
	the field and click the [Add RA] Button. Provided you are all set
	up correctly you should see the same page with "RA <name> Added" at
	the top. The "RA:" Pull-down in the "Add A Region" section should 
	now list your RA.

	Our next step to getting FreeIPdb to do something useful will be to
	add a region. 

	<Tangent>
	What the heck is a region?
	
	A region is a "Pool" of IP space within an RA that may be either
	IPv4 or IPv6(not both). All IP space requests to FreeIPdb require
	a region and will return space from that region. You will likely 
	want to think a little about how you want to define your regions. 
	Some sample region schemes:

		US/MEXICO/CANADA
		North Am./South Am./Asia/Europe/Aust.
		MA/NH/ME/VT/CT/RI
		East/Central/West
		Servers/Desktops/WAN/SAN

	I'll let you go on from there. One way to think of a region is like
	a disk partition. You give 30GB to var and it's used for one type of
	operation another 20GB to /usr and that's for different operations.
	/usr can fill up and not have any adverse effect on /var.
	</Tangent>

	So now find the "Add a Region" section of the admin page. Choose an
	RA from the pull-down. Give your region a name. If you will be putting
	IPv6 IP space in this region check the box. and hit [Add Region]. 
	You should come back to the same page only the region you just added 
	will be in the "Region:" pull-downs.

	Now for the last step before we can get some gratification :-)
	Add an Allocation. Find the "Add Allocation" section. Enter the 
	name of the block so 10.10.10.0 not 10.10.10.0/24. Now the netmask
	so 24 for a class C. Choose a region to add this block to.

	<Tangent>
	What the heck is a priority?

	I use priorities to keep my older allocation at as close to 100%
	use as I can. The lower the number the more likely the block
	is to be used. If the database can find a larger block with a
	lower priority than a block of the correct size it will split the
	block with the better priority. The tool will do anything possible 
	to use a block with a lower priority.
		
	If priority is left null the block will be the last block to be used
	provided there are block with real priority values in that region.
	More than one block with no priority will get used in a quasi-random
	fashion.
	</Tangent>

	Enter a priority. Click [Add]. It should be in there. Now we can
	have some real fun.

	Lets move to the index.cgi. This page is where the day to day
	user functions will take place. I want to see that the Allocation
	we just added made it to the database. Choose "List free blocks"
	from the action pull-down and click [Submit Request].
	You should see a list of all the free blocks in your database. 
	(If you are following along there should be one entry.)
	
	Lets get a block. Go back to the index.cgi page. Set Action to 
	"Request Assignment". Choose the size of the block you want say a 
	/28 or 16 IP addresses. Select a region. You can use the next two 
	fields for some customer or internal tracking information. now click
	[Submit Request]. You should get something like this:

Your New BlockID is : 327 
10.0.23.208/28 from NorthAmerica To: 12333 IPv4 

[Confirm Allocation] [Cancel Allocation]

	If you click the Confirm button the block will be saved as in-use
	if you clock cancel it will be reclaimed and become available again.
	(Note: the browser back button will leave this block in an in-use state)

	Lets do one more thing before we go. Reclaim a block. To do this we 
	need to find the block. we know the the block is a /28 and the region
	is <what ever you choose> so fill them in. Choose "Search for block in 
	database" in the action field and click [Submit Request]. You should
	see your block and maybe others in the list.  Here you can either edit
	or reclaim the block.

	<Tangent>
	A word about reclaims:

	Reclaiming can be fun. It can also cause lots of trouble. Customer
	who think they are done with a block can and do turn-around 10 days
	later and say the need it back. This does not make the Database guy's
	job any easier. We have included the "10 day holding period". When a 
	block is reclaimed it becomes ready to use that instant however there
	is a flag set on that entry so that it will not be reused until the
	10-days have elapsed. (You can use the admin.cgi page to manually 
	assign that block if the customer wants it back.)
	BTW the holdtime is an option in the config.pm file
	</Tangent>

	Thats is for now. 
	
More to come. (wanna contribute? ;-)
