## 3.0.x (unreleased)
- added `--noraid=OK|WARNING|CRITICAL|UNKNOWN` option. defaults to `UNKNOWN`
- setup sudo rules option (`-S`) supports debug (`-d`) and will only print the
  rules. Output is sent to stdout, so you can save that output to file of
  your liking.
- sudo: add `-A` option to use askpass and fail sooner if no sudo rules present

## 3.0.3 (2013-11-12)
- resync fixes

## 3.0.2 (2013-11-11)
- Detecting SCSI devices or hosts with `lsscsi`
- Updated to handle ARCCONF 9.30 output
- Fixed `-W` option handling ([#29][1])
- `dmraid` support
- `mdstat` plugin rewritten to handle external devices ([#34][2])
- added `--resync=OK|WARNING|CRITICAL|UNKNOWN` option. defaults to `OK` ([#23][3], [#24][4], [#28][5], [#37][6]

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


  [1]: https://github.com/glensc/nagios-plugin-check_raid/pull/29
  [2]: https://github.com/glensc/nagios-plugin-check_raid/issues/34
  [3]: https://github.com/glensc/nagios-plugin-check_raid/pull/23
  [4]: https://github.com/glensc/nagios-plugin-check_raid/issues/24
  [5]: https://github.com/glensc/nagios-plugin-check_raid/pull/28
  [6]: https://github.com/glensc/nagios-plugin-check_raid/pull/37
