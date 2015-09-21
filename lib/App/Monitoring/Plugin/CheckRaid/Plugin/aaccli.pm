package App::Monitoring::Plugin::CheckRaid::Plugin::aaccli;

sub new {
	bless {};
}

sub active {
	warn "Called active on aaccli";
	1;
}

1;
