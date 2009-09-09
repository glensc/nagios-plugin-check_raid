# TODO:
# If you call 'check_raid -S' as root it will attempt to add the required lines to the sudoers file in order for itself to work.
%define		plugin	check_raid
Summary:	Nagios plugin to check current server's RAID status
Name:		nagios-plugin-%{plugin}
Version:	2.0
Release:	0.2
License:	Unknown
Group:		Networking
Source0:	%{plugin}
# Source0-md5:	168cc7a68638ed2e07df81c4bd43603a
URL:		http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/RAID-Controllers/check_raid/details
Source1:	%{plugin}.cfg
Requires:	nagios-core
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		_sysconfdir	/etc/nagios/plugins
%define		plugindir	%{_prefix}/lib/nagios/plugins

%description
This plugin chekcs Check all RAID volumes (hardware and software) that
can be identified.

Supports:
- Linux, Solaris and AIX software RAID
- Linux MegaIDE/IPS/Serveraid/MPT/LSI hardware RAID controllers.

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

%files
%defattr(644,root,root,755)
%config(noreplace) %verify(not md5 mtime size) %{_sysconfdir}/%{plugin}.cfg
%attr(755,root,root) %{plugindir}/%{plugin}
