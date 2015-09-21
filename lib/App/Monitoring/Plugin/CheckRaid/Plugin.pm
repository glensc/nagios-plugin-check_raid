package App::Monitoring::Plugin::CheckRaid::Plugin;

use Carp qw(croak);

# constructor for plugins
sub new {
	my $class = shift;

	croak 'Odd number of elements in argument hash' if @_ % 2;

	my $self = {
		@_,

		# name of the plugin, without package namespace
		name => ($class =~ /.*::([^:]+)$/),
	};

	return bless $self, $class;
}

1;
