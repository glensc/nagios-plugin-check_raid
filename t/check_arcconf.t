#!/usr/bin/perl -w
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 20;
use Test::More tests => 3 + TESTS * 6;
use test;

# NOTE: this plugin has side effect of changing dir
use Cwd;
ok(chdir(TESTDIR), "dir changed");
my $cwd = Cwd::cwd();
ok(defined($cwd), "cwd set");

my @tests = (
	{
		status => OK,
		getstatus => '1/getstatus',
		getconfig => '1/getconfig',
		message => 'Controller:Optimal, Logical Device 0:Optimal, Drives: 3LQ1WEH4,3LQ1WEWL=Online',
		c => '1',
	},
	{
		status => OK,
		getstatus => '1/getstatus',
		getconfig => '2/getconfig',
		message => 'Controller:Optimal, Battery Status: Optimal, Battery Capacity Remaining: 100%, Battery Time: 3d16h0m, Logical Device 0:Optimal, Drives: 5000C5000B426E88,500000E01BEFF141=Online',
		c => '2',
	},
	{
		status => OK,
		getstatus => '3/getstatus',
		getconfig => '3/getconfig',
		message => 'Controller:Optimal, ZMM Status: ZMM Optimal, Logical device #0: Build/Verify: In Progress 11%, Logical Device 0(Volume01):Optimal, Drives: *******,*******,*******,*******=Online',
		c => '3',
	},
	{
		status => OK,
		getstatus => '4/arcconf_getstatus_1.out',
		getconfig => '4/arcconf_getconfig_1_al.out',
		message => 'Controller:Okay, Logical Device 1(MailMerak):Okay, Drives: 9QJ2C6NX,GTA060PBGHX61F=Online',
		c => '4',
	},
	{
		status => OK,
		getstatus => 'issue31/getstatus',
		getconfig => 'issue31/getconfig',
		message => 'Controller:Optimal, Logical Device 0(OS):Optimal, Logical Device 1(SSDSTORAGEPOOL):Optimal, Logical Device 2(HDDSTORAGEPOOL):Optimal, Drives: xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx=Online',
		c => 'issue31',
	},
	{
		status => OK,
		getstatus => 'issue47/getstatus',
		getconfig => 'issue47/getconfig',
		message => 'Controller:Optimal, ZMM Status: ZMM not installed, Logical Device 0(data):Optimal, Drives: WD-WCAW36362892,WD-WCAW36407613,WD-WCAW36385723,WD-WCAW36405341=Online',
		c => 'issue47_1',
	},
	{
		status => CRITICAL,
		getstatus => 'issue47/getstatus2',
		getconfig => 'issue47/getconfig2',
		message => 'Controller:Optimal, Degraded drives:1, ZMM Status: ZMM not installed, Logical device #0: Rebuild: In Progress 1%, Logical Device 0(data):Degraded, Drives: WD-*******,WD-*******,WD-*******=Online WD-*******=Rebuilding',
		c => 'issue47_2',
	},
	{
		status => OK,
		getstatus => 'issue55/arcconf-getstatus.out',
		getconfig => 'issue55/arcconf-getconfig.out',
		message => 'Controller:Optimal, Logical Device 0(plop):Optimal, Drives: Y2O483PAS,Y2O3MYTGS,Y2O3M8RGS=Online S1F02BSH=Online (JBOD)',
		c => 'issue55',
	},
	{
		status => OK,
		getstatus => 'issue67/getstatus',
		getconfig => 'issue67/getconfig',
		message => 'Controller:Optimal, Logical Device 0(RAID):Optimal, Drives: 3KS5ABTV0000970648ZZ,3KS5SD1P00009718B64U=Online',
		c => 'issue67',
	},
	{
		status => OK,
		getstatus => 'pr66/arcconf-getstatus.out',
		getconfig => 'pr66/arcconf-getconfig.out',
		message => 'Controller:Optimal, Logical Device 0(OS):Optimal, Logical Device 1(SSDSTORAGEPOOL):Optimal, Logical Device 2(HDDSTORAGEPOOL):Optimal, Drives: S1AXNEAD602232X=Dedicated Hot-Spare for logical device 1 S16LNYAF302137=Dedicated Hot-Spare for logical device 100 S1AXNEAD901256E,S1AXNEAD603771B,9XG4LJ8A00009347BBNG,9XG4JJ2900009346AYKE,9XG4KBA800009347W1Q5,9XG4LBM600009347BBQ0,9XG4LHYX00009347W20M,9XG4LHZG00009347W1RL,S16LNYAF302008,S16LNYAF302181,S19HNEAD592704T,S19HNEAD586378L=Online',
		c => 'pr66',
	},
	{
		status => UNKNOWN, # FIXME
		getstatus => 'issue67/getstatus',
		getconfig => 'issue75/getconfig',
		message => 'Controller:Optimal, ZMM Status: ZMM Optimal, Logical Device 0(OS):Optimal, Logical Device 1(VM-LIVE):Optimal, Logical Device 2(VM-BACKUP):Optimal, Drives: 6SL3PS7P0000N2341WV7,6SL3PYTF0000N237NF8S=Global Hot-Spare 6SL3PXM90000N237HSAJ,6SL3PAAP0000N236HPPM,6SL3MPC80000N237NEB0,6SL3M8310000N238057Y,6SL3PVMD0000N238021B,6SL3GE0F0000N236DGCN,6SL3P03R0000N237CY7E,6SL3PZ3V0000N23765UB,6SL3PRWK0000N237KQLS,6SL3PRHV0000N238063T,6SL3PR3Y0000N237NF0G,6SL3PQN20000N23806DU,6SL3PQSX0000N236DE4Z,6SL3PR7E0000N237EJW3,6SL3PR7H0000N237EMSY,6SL3PQJN0000N23805EQ=Online',
		c => 'issue75',
	},
	{
		status => OK,
		getstatus => 'issue87/getstatus',
		getconfig => 'issue87/getconfig',
		message => 'Controller:Optimal, ZMM Status: ZMM Optimal, Logical Device 0(Sistem):Optimal, Logical Device 1(raid900):Optimal, Logical Device 2(raid200):Optimal, Logical Device 3(raid2t):Optimal, Drives: MK0A31YHGLL0PD,MK0A31YHGLTNWA,3SJ259VW000091089A3K,MK0A31YHGLWK8A=Global Hot-Spare Z1N00XW50000S137KQKX,Z1N00RXM0000S129YCCA,Z1N01CTZ0000S12986FZ,Z1N00TT60000S127K929,3SJ261NE00009108HSF0,3SJ2635B00009107H872,3SJ25CQ600009105PZTP,3SJ262DQ00009107Z22T,3SJ262ES000091089AWR,3SJ261K500009107H72P,3SJ25888000091089D3W,3SJ244YZ00009107YVX3,3SJ256L600009107Y5XD,3SJ25G4N000091089DCA,MK0A31YHGLUS7A,MK0A31YHGLBSTA,MK0A31YHGLU1ZA,MK0A31YHGLT00A,MK0A31YHGM418A,MK0A31YHGLT81A=Online 3SJ2623W00009107YSLV,3NM6XQ2000009905VXVY,3NM5YMFH00009847P9SA,3NM6XPV600009905VY0C,3SD0MT2200009951TXVQ,3SD0M84700009950NH7Y,3NM6XPSQ00009905ULQL=Ready',
		c => 'issue87',
	},
	{
		status => CRITICAL,
		getstatus => 'issue90/b',
		getconfig => 'issue90/c',
		message => 'Controller:Okay, Defunct drives:1, Offline drives:1, Logical Device 0(ARRAY01):Offline, Drives: 0:5=Defunct 9QJ40LQ5,9QJ3ZX84,9QJ3Y860,9QJ3ZX0D,9QJ3ZXZ4=Online',
		c => 'issue90',
	},
	{
		status => OK,
		getstatus => 'issue99/getstatus',
		getconfig => 'issue99/getconfig',
		message => 'Controller:Optimal, Logical Device 0(video):Optimal, Drives: WD-WMC4N0EA309P,WD-WMC4N0D4C3EC,WD-WMC4N0DARL7H,WD-WMC4N0D68KUE,WD-WCC1T0338432,WD-WCC1T0348080,WD-WCC1T0350619,WD-WMC1T1442256,WD-WMC1T1128983,WD-WMC1T0982452,WD-WMC1T1128924,WD-WCC1T0355878,WD-WMC1T1133813,WD-WMC1T0026837,WD-WMC1T1479988,WD-WMC1T3351994=Online',
		c => 'issue99',
	},
	{
		status => CRITICAL,
		getstatus => 'issue105/getstatus',
		getconfig => 'issue105/getconfig',
		message => 'Controller:Optimal, Battery Status: Failed, Logical Device 0(RAID10):Optimal, Drives: WD-WMATV3471115,WD-WMATV3047731,WD-WMATV3036928,WD-WMATV3086188=Online',
		c => 'issue105',
	},
	{
		# test framework doesn't support multiple outputs for same command
		skip => 1,
		status => CRITICAL,
		getstatus => 'issue110/getstatus',
		getconfig => 'issue110/getconfig-1',
		message => 'Controller:Optimal, Defunct drives:1, ZMM Status: ZMM Optimal, Controller:Optimal, Defunct drives:1, ZMM Status: ZMM Optimal, Logical Device 0(Main0):Optimal, Drives: OCZ-B8AV7L1U72V0GT61,22R0A094FRG8,22R0A092FRG8,22R0A03GFRG8,22R0A091FRG8,22R0A03HFRG8,22R0A0A9FRG8,22R0A0A4FRG8=Online',
		c => 'issue110',
	},
	{
		status => CRITICAL,
		getstatus => '86/arcconf-getstatus.out',
		getconfig => '86/arcconf-getconfig.out',
		message => 'Controller:Optimal, Defunct drives:1, Degraded drives:1, Logical Device 0(raid1):Degraded, Drives: 0,1(1:0)=Failed 3KT2ZPHH000076165TAD=Online',
		c => '86',
	},
	{
		status => OK,
		getstatus => 'issue152/arc2_getstatus.txt',
		getconfig => 'issue152/arc2_getconfig.txt',
		message => 'Controller:Optimal, Logical Device 0(mordor):Optimal, Drives: JPW9K0J80A2PLL,Z1N0CB3T,Z1N0CC2Q=Online',
		c => 'issue152',
	},
	{
		status => OK,
		getstatus => 'issue128/getstatus',
		getconfig => 'issue128/getconfig',
		message => 'Controller:OK, Logical Device 0:Optimal, Drives: 0:0,0:1,0:2,0:3,0:4,0:5,0:6,0:7,0:8,0:9,0:10,0:11,0:12,0:13,0:14,0:15=Online',
		c => 'issue128',
	},
	{
		status => CRITICAL,
		getstatus => 'issue155/getstatus',
		getconfig => 'issue155/getconfig',
		message => 'Controller:Optimal, Defunct drives:1, Degraded drives:1, Logical Device 0(HDD):Optimal, Logical Device 1(SSD):Degraded, Drives: 0:2=Failed WD-WMC4M1057040,WD-WMC4M1019533,50026B726900BD5E,WD-WMC4M1311378,WD-WMC4M1081289,50026B726900BD87,50026B726900BD5F=Online',
		c => 'issue155',
	},
	{
		status => OK,
		getstatus => 'issue155/getstatus',
		getconfig => 'pr156/arcconf.txt',
		message => 'Controller:Optimal, Logical Device 0(RAID6-ID0-7):Optimal, Drives: N8GP15YY,N8GPZWEY,N8GPZZ7Y,N8GPYHUY,N8GPZZ3Y,N8GPZZ4Y,N8GPZZ9Y,N8GR000Y=Online',
		c => 'pr156',
	},
);

# test that plugin can be created
ok(arcconf->new, "plugin created");

foreach my $test (@tests) {
	next if $test->{skip};

	my $plugin = arcconf->new(
		commands => {
			getstatus => ['<', $cwd . '/data/arcconf/' . $test->{getstatus}],
			getconfig => ['<', $cwd . '/data/arcconf/' . $test->{getconfig}],
		},
		options => { bbu_monitoring => 1 },
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");

	my $c = $plugin->parse;
	my $df = $cwd. '/dump/arcconf/' . $test->{c};
	if (!-f $df) {
		store_dump $df, $c;
		# trigger error so that we don't have feeling all is ok ;)
		ok(0, "Created dump for $df");
	}
	my $dump = read_dump($df);
	is_deeply($c, $dump, "controller structure");
}
