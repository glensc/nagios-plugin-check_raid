package App::Monitoring::Plugin::CheckRaid;
use Module::Pluggable instantiate => 'new';

sub new {
	bless {};
}

# Get active plugins
sub active_plugins {
	my $this = shift;

	my @plugins = ();

	# go over all registered plugins
	foreach my $plugin ($this->plugins) {
		print $plugin;

		# skip inactive plugins (disabled or no tools available)
		next unless $plugin->active;

		push(@plugins, $plugin->{name});
	}

	return wantarray ? @plugins : \@plugins;
}

1;
