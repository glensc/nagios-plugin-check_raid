package App::Monitoring::Plugin::CheckRaid;

use Carp qw(croak);
use Module::Pluggable 5.1 instantiate => 'new', sub_name => '_plugins';
use strict;
use warnings;

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

	# setup only certain plugins
	if ($self->{enable_plugins}) {
		my @plugins = map {
			__PACKAGE__ . '::Plugins::' . $_
		} @{$self->{enable_plugins}};
		$self->only(\@plugins);
	}

	return $obj;
}

# create list of plugins
sub plugins {
	my ($this) = @_;

	# call this once
	if (!defined $this->{plugins}) {
		my @plugins = $this->_plugins(%$this);
		$this->{plugins} = \@plugins;
	}

	wantarray ? @{$this->{plugins}} : $this->{plugins};
}

# get plugin by name
sub plugin {
	my ($this, $name) = @_;

	if (!defined $this->{plugin_names}) {
		my %names;
		foreach my $plugin ($this->plugins) {
			my $name = $plugin->{name};
			$names{$name} = $plugin;
		}
		$this->{plugin_names} = \%names;
	}

	croak "Plugin '$name' Can not be created" unless exists $this->{plugin_names}{$name};

	$this->{plugin_names}{$name};
}

# Get active plugins.
# Returns the plugin objects
sub active_plugins {
	my $this = shift;
	# whether the query is for sudo rules
	my $sudo = shift || 0;

	my @plugins = ();

	# go over all registered plugins
	foreach my $plugin ($this->plugins) {
		# skip if no check method (not standalone checker)
		next unless $plugin->can('check');

		# skip inactive plugins (disabled or no tools available)
		next unless $plugin->active($sudo);

		push(@plugins, $plugin);
	}

	return wantarray ? @plugins : \@plugins;
}

1;
