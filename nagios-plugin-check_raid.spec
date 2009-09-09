%define		plugin	check_raid
Summary:	Nagios plugin to check current server's RAID status
Name:		nagios-plugin-%{plugin}
Version:	2.0
Release:	0.1
License:	Unknown
Group:		Networking
Source0:	%{plugin}
# Source0-md5:	168cc7a68638ed2e07df81c4bd43603a
URL:		http://www.monitoringexchange.org/cgi-bin/page.cgi?g=Detailed/1692.html;d=1
Source1:	%{plugin}.cfg
Requires:	nagios-core
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		_sysconfdir	/etc/nagios/plugins
%define		plugindir	%{_prefix}/lib/nagios/plugins

%description
This plugin reports the current server's RAID status.

Supports:
- IPS; Solaris, AIX, Linux software RAID; megaide
- megaraid, mpt (serveraid), aacli (serveraid)

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
