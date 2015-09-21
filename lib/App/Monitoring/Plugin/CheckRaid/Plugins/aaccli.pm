package App::Monitoring::Plugin::CheckRaid::Plugins::aaccli;

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';

sub active {
	1;
}

sub check {
	my $this = shift;

	$this->add_message(CRITICAL, "Epic Fail");
	$this->add_message(OK, "Not so Epic Fail");
}

1;
