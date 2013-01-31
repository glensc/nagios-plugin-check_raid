# Nagios plugin to check current server's RAID status

This plugin checks all RAID volumes (hardware and software) that can be
identified.

This is supposed to be a general plugin to run via NRPE.
It checks for the various RAID systems, and verifies they are working correctly.

Some checks require root permission, that is acomplished using sudo.
Neccessary sudo rules (detected for your system), can be installed when
`check_raid` is invoked with -S argument. You need to be root user and it
will add required lines to the sudoers file.

## Relese Notes

This project is a fork from https://github.com/glensc/nagios-plugin-check_raid

This version supports force the use a defined plugin. The consequence is a 
improvement of execution time because is not needed initialize all plugins
to execute the check.
This version also lists the active plugins.... Usefull information to install the plugin



## Installing

Download directly from github release (with wget or curl):

    wget https://raw.github.com/glensc/nagios-plugin-check_raid/master/check_raid.pl -O check_raid.pl
    curl https://raw.github.com/glensc/nagios-plugin-check_raid/master/check_raid.pl > check_raid.pl
    chmod +x check_raid
    
or download whole release tarball:

    wget https://github.com/glensc/nagios-plugin-check_raid/tarball/master/check_raid.tgz
    tar xzf check_raid.tgz
    cd glensc-nagios-plugin-check_raid-*
    
setup `sudo`

    ./check_raid.pl -S

test run

    ./check_raid.pl

for some RAIDs there's need to install extra tools, see [Supported RAIDs](#supported-raids)


## Usage

	./check_raid.pl [-p|--plugin <name>] [-d|--debug] [-w|--warnonly]
	./check_raid.pl -S
	./check_raid.pl -l

Command line arguments

	-d	--debug				Show debug information
	-l	--list-plugins		Lists active plugins 	
	-p	--plugin <name>		Force the use of selected plugin
	-S	--sudoers			Configure /etc/sudoers file
	-w	--warnonly			Don't send CRITICAL status

	
## Supported RAIDs

Supported RAIDs that can be checked:
- Adaptec AAC RAID via aaccli or afacli or arcconf
- AIX software RAID via lsvg
- HP/Compaq Smart Array via cciss_vol_status (hpsa supported too)
- HP Smart Array Controllers and MSA Controllers via hpacucli (see
  hapacucli readme)
- HP Smart Array (MSA1500) via serial line
- Linux 3ware SATA RAID via tw_cli
- Linux DPT/I2O hardware RAID controllers via /proc/scsi/dpt_i2o
- Linux GDTH hardware RAID controllers via /proc/scsi/gdth
- Linux LSI MegaRaid hardware RAID via CmdTool2
- Linux LSI MegaRaid hardware RAID via megarc
- Linux LSI MegaRaid hardware RAID via /proc/megaraid
- Linux MegaIDE hardware RAID controllers via /proc/megaide
- Linux MPT hardware RAID via mpt-status
- Linux software RAID (md) via /proc/mdstat
- LSI Logic MegaRAID SAS series via MegaCli
- LSI MegaRaid via lsraid
- Serveraid IPS via ipssend
- Solaris software RAID via metastat

You might need to install following tools depending on your raid:
- CmdTool2: CmdTool2 SAS RAID Management Utility
- arcconf: Adaptec uniform command line interface
- cciss_vol_status: http://cciss.sourceforge.net/
- megarc-scsi: LSI Logic MegaRAID Linux MegaRC utility
- mpt-status: LSI RAID controllers - http://www.red-bean.com/~mab/mpt-status.html
- tw_cli-9xxx: 3ware SATA RAID controllers - http://www.3ware.com/

Project entry in Nagios Exchange: http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/RAID-Controllers/check_raid/details

## Copyright
License: GPL v2

(c) 2004-2006 Steve Shipway, university of auckland,
http://www.steveshipway.org/forum/viewtopic.php?f=20&t=417&p=3211
Steve Shipway Thanks M Carmier for megaraid section.

(c) 2009-2012 Elan Ruusamäe <glen@pld-linux.org>
