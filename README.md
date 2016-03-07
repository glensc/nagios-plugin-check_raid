# Nagios/Icinga plugin to check current server's RAID status

This plugin checks all RAID volumes (hardware and software) that can be
identified.

This is supposed to be a general plugin to run via NRPE.
It checks for the various RAID systems, and verifies they are working correctly.

Some checks require root permission, that is acomplished using `sudo`.
Neccessary `sudo` rules (detected for your system), can be installed when
`check_raid` is invoked with `-S` argument. You need to be `root` user and it
will add required lines to the sudo config file.

[![Build Status](https://travis-ci.org/glensc/nagios-plugin-check_raid.png?branch=master)](https://travis-ci.org/glensc/nagios-plugin-check_raid)

## Reporting bugs

**IMPORTANT**: See [CONTRIBUTING.md](CONTRIBUTING.md) what is needed for your reported *Issue* to be worked on or *Pull Request* to be accepted.

Failure to do so means I will just have to ignore your *Issue* or *Pull Request* and will eventually close with no resolution. Currently [there are too many](https://github.com/glensc/nagios-plugin-check_raid/labels/need%20test%20data) of such tickets.

## Installing

Download latest release from [releases](https://github.com/glensc/nagios-plugin-check_raid/releases) page

next step would be to setup system `sudo` rules:

    ./check_raid.pl -S

run with `-d` to preview the sudo rules.

Plugin should be ready to be run:

    ./check_raid.pl

for some RAIDs there's need to install extra tools, see [Supported RAIDs](#supported-raids)

## Development

To obtain latest development version of the plugin source, grab [tarball](https://github.com/glensc/nagios-plugin-check_raid/archive/master/check_raid.tar.gz) or do a git checkout:

    git clone --depth=8 https://github.com/glensc/nagios-plugin-check_raid

to build self-contained [fatpacked](http://www.perladvent.org/2012/2012-12-14.html) `check_raid.pl`, invoke `make pack`, otherwise use `check_raid.sh` in project root to run the plugin in source tree.

## Usage

	./check_raid.pl [-p|--plugin <name>] [-w|--warnonly]
	./check_raid.pl -S
	./check_raid.pl -l

Command line arguments

	-V  --version           Print check_raid version
	-d                      Produce some debug output
	-S  --sudoers           Configure /etc/sudoers file
	-W  --warnonly          Don't send CRITICAL status
	-p  --plugin <name(s)>  Force the use of selected plugins, comma separated
	    --noraid=STATE      Set status as STATE if RAID controller is found. Defaults to `UNKNOWN`
	    --resync=STATE      Set status as STATE if RAID is in resync state. Defaults to `WARNING`
	    --check=STATE       Set status as STATE if RAID is in check state. Defaults to `OK`
	    --cache-fail=STATE  Set status as STATE if Write Cache is present but disabled. Defaults to `WARNING`
	    --bbulearn=STATE    Return STATE if Backup Battery Unit (BBU) learning cycle is in progress. Defaults to `WARNING`
	    --bbu-monitoring    Enable experimental monitoring of the BBU status
	-l  --list-plugins      Lists active plugins

`STATE` can be one of: `OK`, `WARNING`, `CRITICAL`, `UNKNOWN`

## Supported RAIDs

Supported RAIDs that can be checked:

- Adaptec AAC RAID via `aaccli` or `afacli` or `arcconf`
- AIX software RAID via `lsvg`
- HP/Compaq Smart Array via `cciss_vol_status` (hpsa supported too)
- HP Smart Array Controllers and MSA Controllers via `hpacucli` and `hpssacli`
- HP Smart Array (MSA1500) via serial line
- Linux 3ware SATA RAID via `tw_cli`
- Linux Device Mapper RAID via dmraid
- Linux DPT/I2O hardware RAID controllers via `/proc/scsi/dpt_i2o`
- Linux GDTH hardware RAID controllers via `/proc/scsi/gdth`
- Linux LSI MegaRaid hardware RAID via CmdTool2
- Linux LSI MegaRaid hardware RAID via megarc
- Linux LSI MegaRaid hardware RAID via `/proc/megaraid`
- Linux LVM RAID
- Linux MegaIDE hardware RAID controllers via `/proc/megaide`
- Linux MPT hardware RAID via mpt-status
- Linux software RAID (md) via `/proc/mdstat`
- LSI Logic MegaRAID SAS series via MegaCli
- LSI MegaRaid via lsraid
- Serveraid IPS via ipssend
- Solaris software RAID via metastat

You might need to install following tools depending on your raid:

- `CmdTool2`: CmdTool2 SAS RAID Management Utility
- `arcconf`: Adaptec uniform command line interface
- `cciss_vol_status`: http://cciss.sourceforge.net/
- `dmraid`: Device Mapper RAID command line interface
- `megarc-scsi`: LSI Logic MegaRAID Linux MegaRC utility
- `mpt-status`: LSI RAID controllers - http://www.red-bean.com/~mab/mpt-status.html
- `tw_cli-9xxx`: 3ware SATA RAID controllers - http://www.3ware.com/

Project entry in Nagios Exchange: http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/RAID-Controllers/check_raid/details

## Copyright
License: GPL v2

(c) 2004-2006 Steve Shipway (code up to version 2.1), university of auckland,
http://www.steveshipway.org/forum/viewtopic.php?f=20&t=417&p=3211
Steve Shipway Thanks M Carmier for megaraid section.

(c) 2009-2016 Elan Ruusamäe <glen@pld-linux.org> (maintainer from version 2.1 and upwards)



[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/glensc/nagios-plugin-check_raid/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
