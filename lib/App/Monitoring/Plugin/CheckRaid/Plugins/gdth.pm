package App::Monitoring::Plugin::CheckRaid::Plugins::gdth;

# Linux gdth RAID

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub commands {
	{
		'proc' => ['<', '/proc/scsi/gdth'],
		'proc entry' => ['<', '/proc/scsi/gdth/$controller'],
	}
}

sub active {
	my ($this) = @_;
	return -d $this->{commands}{proc}[1];
}

sub parse {
	my $this = shift;

	my $fh = $this->cmd('proc');
	my @c = grep { !/^\./ } readdir($fh);
	close($fh);

	my %c;
	for my $c (@c) {
		my (%ld, %ad, %pd, %l, %a, %p, $section);

		my $fh = $this->cmd('proc entry', { '$controller' => $c });
		while (<$fh>) {
			chomp;

			# new section start
			if (my($s) = /^(\w.+):$/) {
				$section = $s;
				%a = %l = %p = ();
				next;
			}

			# skip unknown sections
			next unless /^\s/ or /^$/;

			# process each section
			if ($section eq 'Driver Parameters') {
				# nothing useful
			} elsif ($section eq 'Disk Array Controller Information') {
				# nothing useful
			} elsif ($section eq 'Physical Devices') {
				# Chn/ID/LUN:        B/05/0          Name:           FUJITSU MAX3147NC       0104
				# Capacity [MB]:     140239          To Log. Drive:  5
				# Retries:           1               Reassigns:      0
				# Grown Defects:     1

				if (my($id, $n, $rv) = m{^\s+Chn/ID/LUN:\s+(\S+)\s+Name:\s+(.+)(.{4})$}) {
					$n =~ s/\s+$//;
					$p{id} = $id;
					$p{name} = $n;
					$p{revision} = $rv;
				} elsif (my($unit, $c, $d) = m/^\s+Capacity\s\[(.B)\]:\s+(\d+)\s+To Log\. Drive:\s+(\d+|--)/) {
					$p{capacity} = int($c);
					$p{capacity_unit} = $unit;
					$p{drive} = $d;
				} elsif (my($r, $ra) = m/^\s+Retries:\s+(\d+)\s+Reassigns:\s+(\d+)/) {
					$p{retries} = int($r);
					$p{reassigns} = int($ra);
				} elsif (my($gd) = m/^\s+Grown Defects:\s+(\d+)/) {
					$p{defects} = int($gd);
				} elsif (/^$/) {
					if ($p{capacity} == 0 and $p{name} =~ /SCA HSBP/) {
						# HSBP is not a disk, so do not consider this an error
						# http://support.gateway.com/s/Servers/COMPO/MOTHERBD/4000832/4000832si69.shtml
						# Raid Hot Swap Backplane driver (recognized as "ESG-SHV SCA HSBP M16 SCSI Processor Device")
						# Chn/ID/LUN:    B/06/0          Name:           ESG-SHV SCA HSBP M16    0.05
						# Capacity [MB]: 0               To Log. Drive:  --
						next;
					}

					$pd{$p{id}} = { %p };
				} else {
					warn "[$section] [$_]";
					$this->unknown;
				}

			} elsif ($section eq 'Logical Drives') {
				# Number:              3               Status:         ok
				# Slave Number:        15              Status:         ok (older kernels)
				# Capacity [MB]:       69974           Type:           Disk
				if (my($num, $s) = m/^\s+(?:Slave )?Number:\s+(\d+)\s+Status:\s+(\S+)/) {
					$l{number} = int($num);
					$l{status} = $s;
				} elsif (my($unit, $c, $t) = m/^\s+Capacity\s\[(.B)\]:\s+(\d+)\s+Type:\s+(\S+)/) {
					$l{capacity} = "$c $unit";
					$l{type} = $t;
				} elsif (my($md, $id) = m/^\s+Missing Drv\.:\s+(\d+)\s+Invalid Drv\.:\s+(\d+|--)/) {
					$l{missing} = int($md);
					$l{invalid} = int($id);
				} elsif (my($n) = m/^\s+To Array Drv\.:\s+(\d+|--)/) {
					$l{array} = $n;
				} elsif (/^$/) {
					$ld{$l{number}} = { %l };
				} else {
					warn "[$section] [$_]";
					$this->unknown;
				}

			} elsif ($section eq 'Array Drives') {
				# Number:        0               Status:         fail
				# Capacity [MB]: 349872          Type:           RAID-5
				if (my($num, $s) = m/^\s+Number:\s+(\d+)\s+Status:\s+(\S+)/) {
					$a{number} = int($num);
					$a{status} = $s;
				} elsif (my($unit, $c, $t) = m/^\s+Capacity\s\[(.B)\]:\s+(\d+)\s+Type:\s+(\S+)/) {
					$a{capacity} = "$c $unit";
					$a{type} = $t;
				} elsif (/^(?: --)?$/) {
					if (%a) {
						$ad{$a{number}} = { %a };
					}
				} else {
					warn "[$section] [$_]";
					$this->unknown;
				}

			} elsif ($section eq 'Host Drives') {
				# nothing useful
			} elsif ($section eq 'Controller Events') {
				# nothing useful
			}
		}
		close($fh);

		$c{$c} = { id => $c, array => { %ad }, logical => { %ld }, physical => { %pd } };
	}

	return \%c;
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $controllers = $this->parse;

	# process each controller separately
	for my $c (values %$controllers) {
		# array status
		my @ad;
		for my $n (sort {$a cmp $b} keys %{$c->{array}}) {
			my $ad = $c->{array}->{$n};
			if ($ad->{status} ne "ready") {
				$this->critical;
			}
			push(@ad, "Array $ad->{number}($ad->{type}) $ad->{status}");
		}

		# older raids have no Array drives, Look into Logical Drives for type!=Disk
		unless (@ad) {
			for my $n (sort {$a cmp $b} keys %{$c->{logical}}) {
				my $ld = $c->{logical}->{$n};
				if ($ld->{type} eq "Disk") {
					next;
				}

				# emulate Array Drive
				my $s = "Array($ld->{type}) $ld->{status}";
				# check for missing drives
				if ($ld->{missing} > 0) {
					$this->warning;
					$s .= " ($ld->{missing} missing drives)";
				}

				push(@ad, $s);
			}
		}

		# logical drive status
		my %ld;
		for my $n (sort {$a cmp $b} keys %{$c->{logical}}) {
			my $ld = $c->{logical}->{$n};
			if ($ld->{status} ne "ok") {
				$this->critical;
			}
			push(@{$ld{$ld->{status}}}, $ld->{number});
		}

		# physical drive status
		my @pd;
		for my $n (sort {$a cmp $b} keys %{$c->{physical}}) {
			my $pd = $c->{physical}->{$n};

			my @ds;
			# TODO: make tresholds configurable
			if ($pd->{defects} > 300) {
				$this->critical;
				push(@ds, "grown defects critical: $pd->{defects}");
			} elsif ($pd->{defects} > 30) {
				$this->warning;
				push(@ds, "grown defects warning: $pd->{defects}");
			}

			# report disk being not assigned
			if ($pd->{drive} eq '--') {
				push(@ds, "not assigned");
			}

			if (@ds) {
				push(@pd, "Disk $pd->{id}($pd->{name}) ". join(', ', @ds));
			}
		}

		my @cd;
		push(@cd, @ad) if @ad;
		push(@cd, "Logical Drives: ". $this->join_status(\%ld));
		push(@cd, @pd) if @pd;
		push(@status, "Controller $c->{id}: ". join('; ', @cd));
	}

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join('; ', @status));
}

1;
