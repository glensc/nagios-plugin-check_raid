%define		plugin	check_raid
Summary:	Nagios plugin to check current server's RAID status
Name:		nagios-plugin-%{plugin}
Version:	2.1
Release:	4
License:	GPL v2
Group:		Networking
Source0:	%{plugin}
URL:		http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/RAID-Controllers/check_raid/details
Source1:	%{plugin}.cfg
Requires:	nagios-core
Requires:	sudo
Suggests:	CmdTool2
Suggests:	arcconf
Suggests:	cciss_vol_status
Suggests:	megarc-scsi
Suggests:	mpt-status
Suggests:	tw_cli-9xxx
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		_sysconfdir	/etc/nagios/plugins
%define		plugindir	%{_prefix}/lib/nagios/plugins

%description
This plugin chekcs Check all RAID volumes (hardware and software) that
can be identified.

Supports:
- Linux, Solaris and AIX software RAID
- Linux MegaIDE/IPS/Serveraid/MPT/LSI/GDTH/I2O hardware RAID controllers.
- 3ware SATA RAID
- Adaptec AAC RAID
- LSI MegaRaid
- HP/Compaq Smart Array

%prep
%setup -qcT
cp -p %{SOURCE0} %{plugin}

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT{%{_sysconfdir},%{plugindir}}
install -p %{plugin} $RPM_BUILD_ROOT%{plugindir}/%{plugin}
sed -e 's,@plugindir@,%{plugindir},' %{SOURCE1} > $RPM_BUILD_ROOT%{_sysconfdir}/%{plugin}.cfg

%clean
rm -rf $RPM_BUILD_ROOT

%post
if [ "$1" = 1 ]; then
	# setup sudo rules on first install
	%{plugindir}/%{plugin} -S || :
fi

%postun
if [ "$1" = 0 ]; then
	# remove all sudo rules related to us
	%{__sed} -i -e '/CHECK_RAID/d' /etc/sudoers
fi

%files
%defattr(644,root,root,755)
%config(noreplace) %verify(not md5 mtime size) %{_sysconfdir}/%{plugin}.cfg
%attr(755,root,root) %{plugindir}/%{plugin}
