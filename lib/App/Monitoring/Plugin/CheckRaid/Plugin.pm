package App::Monitoring::Plugin::CheckRaid::Plugin;

use Carp qw(croak);
use strict;
use warnings;

# constructor for plugins
sub new {
	my $class = shift;

	croak 'Odd number of elements in argument hash' if @_ % 2;
	croak 'Class is already a reference' if ref $class;

	my $self = {
		@_,

		# name of the plugin, without package namespace
		name => ($class =~ /.*::([^:]+)$/),
	};

	return bless $self, $class;
}

# Add $message of type $code
sub add_message {
	my ($this, $code, $message) = @_;

	$this->{mp}->add_message($code, $message);
}

1;
