%define		plugin	check_raid
Summary:	Nagios plugin to check current server's RAID status
Name:		nagios-plugin-%{plugin}
Version:	0.1
Release:	0.1
License:	Unknown
Group:		Networking
# Source0Download:	https://secure.opsera.com/wsvn/wsvn/opsview/trunk/opsview-core/nagios-plugins/check_raid?op=dl
Source0:	%{plugin}
Requires:	nagios-core
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		_sysconfdir	/etc/nagios/plugins
%define		plugindir	%{_prefix}/lib/nagios/plugins

%description
This plugin reports the current server's RAID status.

%prep
%setup -qcT
cp -p %{SOURCE0} %{plugin}

cat > nagios.cfg <<'EOF'
# Usage:
# %{plugin}
define command {
	command_name    %{plugin}
	command_line    %{plugindir}/%{plugin}
}
EOF

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT{%{_sysconfdir},%{plugindir}}
install -p %{plugin} $RPM_BUILD_ROOT%{plugindir}/%{plugin}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%attr(755,root,root) %{plugindir}/%{plugin}
