package App::Monitoring::Plugin::CheckRaid;

use Carp qw(croak);
use Module::Pluggable instantiate => 'new';

# constructor
sub new {
	my $class = shift;

	croak 'Odd number of elements in argument hash' if @_ % 2;

	my $self = {
		@_,
	};

	my $obj = bless $self, $class;

	# setup search path for Module::Pluggable
	$self->search_path(add => __PACKAGE__ . '::Plugins');

	return $obj;
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
