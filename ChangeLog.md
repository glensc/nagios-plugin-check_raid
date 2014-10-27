## Unreleased

- cciss: fix parsing enclosure with no enclosure name [#84][]
- megacli: actually report that cache is disabled. [#85][]
- arcconf: accept 'Ready' as OK drive state. [#87][]
- tw_cli: tweak VERIFYING state [#89][]

## 3.2.1 (2014-10-07)

- cciss: fix parsing enclosure with space and no serial [#83][]
- megacli: alert if default is WriteBack, but current is WriteThrough. [#65][]

NOTE: megacli now checks cache state, use `--cache-fail=STATE` if default `WARNING` is not for you.

## 3.2.0 (2014-09-21)
- sudoers: support `#includedir` if enabled in sudoers config
- tw_cli: rewritten with full data parsing
- cciss: rewritten with full data parsing, optionally use lsscsi to find controller devices

NOTE: when using `cciss` plugin with `hpsa` kernel driver, install `lsscsi` program and `cciss_vol_status` 1.10+ to get best results. `cciss_vol_status` v1.10 enables check of individual disks and their S.M.A.R.T status.

## 3.1.0 (2014-09-08)
- sudoers: disable requiretty (enabled in CentOS 6.5) [#52][]
- megacli fixes [#50][], [#53][], [#56][], [#63][], [#74][], [#32][]
- arcconf fixes [#47][], [#51][], [#55][], [#67][], [#68][], [#66][]
- mpt-status fixes [#36][], [#57][]
- add `/opt/bin` to `$PATH` [#54][]
- add travis integration
- hpacucli fixes [#62][]
- mdstat auto-readonly raid fix [#64][]
- areca fixes [#72][]
- dmraid detect fixes [#60][]
- mdstat: do not trigger WARN when checking (even multiple) arrays by default [#77][]
- fixed behaviour of `--noraid` option [#70][]
- sas2ircu: add disks check, handle no RAID volumes [#71][]

NOTES:
`mpt-status` and `sas2ircu` users need to update their `sudo` rules

## 3.0.5 (2013-11-27)

- fixed program version

## 3.0.4 (2013-11-25)
- added `--noraid=OK|WARNING|CRITICAL|UNKNOWN` option. defaults to `UNKNOWN`
- setup sudo rules option (`-S`) supports debug (`-d`) and will only print the
  rules. Output is sent to stdout, so you can save that output to file of
  your liking.
- sudo: add `-A` option to use askpass and fail sooner if no sudo rules present
- arcconf: check physical devices
- megacli: Fixed handling of multiple Virtual Drive without name
- megacli: Batteries check (megacli), perfdata, longoutput, and `--noraidok` option ([#39][], [#33][])
- megacli: reports CRITICAL on Battery state Optimal ([#45][], [#46][])
- set state WARNING when raid is resyncing by default, override with `--resync=STATE`
- arcconf: check physical devices

## 3.0.3 (2013-11-12)
- resync fixes

## 3.0.2 (2013-11-11)
- Detecting SCSI devices or hosts with `lsscsi`
- Updated to handle ARCCONF 9.30 output
- Fixed `-W` option handling ([#29][])
- `dmraid` support ([#35][])
- `mdstat` plugin rewritten to handle external devices ([#34][])
- added `--resync=OK|WARNING|CRITICAL|UNKNOWN` option. defaults to `OK` ([#23][], [#24][], [#28][], [#37][])

## 3.0.1
- Fixes to `cciss` plugin, improvements in `mpt`, `areca`, `mdstat` plugins

## 2.2
- Project moved to [github](https://github.com/glensc/nagios-plugin-check_raid)
- SAS2IRCU support
- Areca SATA RAID Support

## 2.1
- Made script more generic and secure
- Added `gdth`
- Added `dpt_i2o`
- Added 3ware SATA RAID
- Added Adaptec AAC-RAID via `arcconf`
- Added LSI MegaRaid via `megarc`
- Added LSI MegaRaid via `CmdTool2`
- Added HP/Compaq Smart Array via `cciss_vol_status`
- Added HP MSA1500 check via serial line
- Added checks via HP `hpacucli` utility.
- Added `hpsa` module support for cciss_vol_status
- Added `smartctl` checks for cciss disks

## 2.0
- Added `megaraid`, `mpt` (`serveraid`), `aaccli` (`serveraid`)

## 1.1
- IPS; Solaris, AIX, Linux software RAID; `megaide`

[#23]: https://github.com/glensc/nagios-plugin-check_raid/pull/23
[#24]: https://github.com/glensc/nagios-plugin-check_raid/issues/24
[#28]: https://github.com/glensc/nagios-plugin-check_raid/pull/28
[#29]: https://github.com/glensc/nagios-plugin-check_raid/pull/29
[#33]: https://github.com/glensc/nagios-plugin-check_raid/issues/33
[#34]: https://github.com/glensc/nagios-plugin-check_raid/issues/34
[#35]: https://github.com/glensc/nagios-plugin-check_raid/pull/35
[#36]: https://github.com/glensc/nagios-plugin-check_raid/issues/36
[#37]: https://github.com/glensc/nagios-plugin-check_raid/pull/37
[#39]: https://github.com/glensc/nagios-plugin-check_raid/pull/39
[#45]: https://github.com/glensc/nagios-plugin-check_raid/issues/45
[#46]: https://github.com/glensc/nagios-plugin-check_raid/pull/46
[#47]: https://github.com/glensc/nagios-plugin-check_raid/issues/47
[#50]: https://github.com/glensc/nagios-plugin-check_raid/issues/50
[#51]: https://github.com/glensc/nagios-plugin-check_raid/issues/51
[#52]: https://github.com/glensc/nagios-plugin-check_raid/issues/52
[#53]: https://github.com/glensc/nagios-plugin-check_raid/issues/53
[#54]: https://github.com/glensc/nagios-plugin-check_raid/issues/54
[#55]: https://github.com/glensc/nagios-plugin-check_raid/issues/55
[#56]: https://github.com/glensc/nagios-plugin-check_raid/issues/56
[#57]: https://github.com/glensc/nagios-plugin-check_raid/pull/57
[#62]: https://github.com/glensc/nagios-plugin-check_raid/pull/62
[#63]: https://github.com/glensc/nagios-plugin-check_raid/issues/63
[#64]: https://github.com/glensc/nagios-plugin-check_raid/issues/64
[#67]: https://github.com/glensc/nagios-plugin-check_raid/issues/67
[#68]: https://github.com/glensc/nagios-plugin-check_raid/pull/68
[#74]: https://github.com/glensc/nagios-plugin-check_raid/pull/74
[#72]: https://github.com/glensc/nagios-plugin-check_raid/pull/72
[#60]: https://github.com/glensc/nagios-plugin-check_raid/pull/60
[#77]: https://github.com/glensc/nagios-plugin-check_raid/pull/77
[#66]: https://github.com/glensc/nagios-plugin-check_raid/pull/66
[#70]: https://github.com/glensc/nagios-plugin-check_raid/pull/70
[#71]: https://github.com/glensc/nagios-plugin-check_raid/pull/71
[#32]: https://github.com/glensc/nagios-plugin-check_raid/issues/32
[#83]: https://github.com/glensc/nagios-plugin-check_raid/issues/83
[#65]: https://github.com/glensc/nagios-plugin-check_raid/issues/65
[#84]: https://github.com/glensc/nagios-plugin-check_raid/issues/84
[#85]: https://github.com/glensc/nagios-plugin-check_raid/issues/85
[#87]: https://github.com/glensc/nagios-plugin-check_raid/issues/87
[#89]: https://github.com/glensc/nagios-plugin-check_raid/pull/89
