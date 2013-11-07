# Nagios plugin to check current server's RAID status

This plugin checks all RAID volumes (hardware and software) that can be
identified.

This is supposed to be a general plugin to run via NRPE.
It checks for the various RAID systems, and verifies they are working correctly.

Some checks require root permission, that is acomplished using `sudo`.
Neccessary `sudo` rules (detected for your system), can be installed when
`check_raid` is invoked with `-S` argument. You need to be `root` user and it
will add required lines to the `sudoers` file.

## Installing

Download directly from github master (with wget or curl):

    wget https://raw.github.com/glensc/nagios-plugin-check_raid/master/check_raid.pl -O check_raid.pl
    curl https://raw.github.com/glensc/nagios-plugin-check_raid/master/check_raid.pl > check_raid.pl
    chmod +x check_raid.pl

or download in tar format master checkout:

    wget https://github.com/glensc/nagios-plugin-check_raid/tarball/master/check_raid.tgz
    tar xzf check_raid.tgz
    cd glensc-nagios-plugin-check_raid-*

you can grab older releases under [tags](https://github.com/glensc/nagios-plugin-check_raid/tags) button

next, setup `sudo`

    ./check_raid.pl -S

test run:

    ./check_raid.pl

for some RAIDs there's need to install extra tools, see [Supported RAIDs](#supported-raids)


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
	-l  --list-plugins      Lists active plugins

## Reporting bugs

Bugs should be reported to [github issue tracker](https://github.com/glensc/nagios-plugin-check_raid/issues).
Before opening new issue, check that your problem is not already reported,
also before opening bugreport, check that the bug is not already fixed by testing with master branch.

As it's unlikely I have same hardware as you, not to mention same condition that is not handled,
I ask you to provide output of the commands the plugin runs.
What commands plugin runs, can be seen with `-d` option:

    DEBUG EXEC: /proc/mdstat at ./check_raid.pl line 345.
    DEBUG EXEC: /usr/local/bin/arcconf GETSTATUS 1 at ./check_raid.pl line 345.
    DEBUG EXEC: /usr/local/bin/arcconf GETCONFIG 1 AL at ./check_raid.pl line 345.

Capture each command output to a file:

    cat /proc/mdstat > mdstat.out
    /usr/local/bin/arcconf GETSTATUS 1 > arcconf-getstatus.out
    /usr/local/bin/arcconf GETCONFIG 1 AL > arcconf-getconfig.out

In this particular example, the space between `1` and `>` is important, because `1>` means different thing (tells shell to redirect fd no 1).

The redirection commands should provide no output, all should be directed to `.out` file.
If they do, it means the command produced output to `stderr` stream as well.
Depending on the output, it may make difference what that is,
usually those messages are small and can be included with bugreport.

The command output should be shared by some pastebin service, maybe even [gist](https://gists.github.com) because it may be important how the output is formatted, some invisible bytes may make the difference. You may include the output in github reports if you enclose the block between triple backticks:

    ```
    some output here...
    ```

## Supported RAIDs

Supported RAIDs that can be checked:

- Adaptec AAC RAID via `aaccli` or `afacli` or `arcconf`
- AIX software RAID via `lsvg`
- HP/Compaq Smart Array via `cciss_vol_status` (hpsa supported too)
- HP Smart Array Controllers and MSA Controllers via `hpacucli` (see
  hapacucli readme)
- HP Smart Array (MSA1500) via serial line
- Linux 3ware SATA RAID via `tw_cli`
- Linux DPT/I2O hardware RAID controllers via `/proc/scsi/dpt_i2o`
- Linux GDTH hardware RAID controllers via `/proc/scsi/gdth`
- Linux LSI MegaRaid hardware RAID via CmdTool2
- Linux LSI MegaRaid hardware RAID via megarc
- Linux LSI MegaRaid hardware RAID via `/proc/megaraid`
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
- `megarc-scsi`: LSI Logic MegaRAID Linux MegaRC utility
- `mpt-status`: LSI RAID controllers - http://www.red-bean.com/~mab/mpt-status.html
- `tw_cli-9xxx`: 3ware SATA RAID controllers - http://www.3ware.com/

Project entry in Nagios Exchange: http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/RAID-Controllers/check_raid/details

## Copyright
License: GPL v2

(c) 2004-2006 Steve Shipway (code up to version 2.1), university of auckland,
http://www.steveshipway.org/forum/viewtopic.php?f=20&t=417&p=3211
Steve Shipway Thanks M Carmier for megaraid section.

(c) 2009-2013 Elan Ruusamäe <glen@pld-linux.org> (maintainer from version 2.1 and upwards)

