package App::Monitoring::Plugin::CheckRaid;
use Module::Pluggable instantiate => 'new';

sub new {
	bless {};
}

# Get active plugins.
# Returns the plugin objects
sub active_plugins {
	my $this = shift;

	my @plugins = ();

	# go over all registered plugins
	foreach my $plugin ($this->plugins) {
		# skip inactive plugins (disabled or no tools available)
		next unless $plugin->active;

		push(@plugins, $plugin);
	}

	return wantarray ? @plugins : \@plugins;
}

1;
