package hpssacli;
# extend hpacucli,
# with the only difference that different program name is used
use parent -norequire, 'hpacucli';

push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(hpssacli);
}

1;
