package App::Monitoring::Plugin::CheckRaid::aaccli;

sub new {
	bless {};
}

sub active {
	warn "Called active on aaccli";
	1;
}

1;
