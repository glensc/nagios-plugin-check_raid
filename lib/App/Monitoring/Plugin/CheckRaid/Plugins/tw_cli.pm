package tw_cli;
# tw_cli(8) is a Command Line Interface Storage Management Software for
# AMCC/3ware ATA RAID Controller(s).
# Owned by LSI currently: https://en.wikipedia.org/wiki/3ware
#
# http://www.cyberciti.biz/files/tw_cli.8.html
use parent -norequire, 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(tw_cli-9xxx tw_cli tw-cli);
}

sub commands {
	{
		'info' => ['-|', '@CMD', 'info'],
		'unitstatus' => ['-|', '@CMD', 'info', '$controller', 'unitstatus'],
		'drivestatus' => ['-|', '@CMD', 'info', '$controller', 'drivestatus'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd info*";
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

sub to_i {
	my $i = shift;
	return $i if $i !~ /^\d+$/;
	return int($i);
}

sub parse {
	my $this = shift;

	my (%c);
	# scan controllers
	my $fh = $this->cmd('info');
	while (<$fh>) {
		if (my($ctl, $model, $ports, $drives, $units, $notopt, $rrate, $vrate, $bbu) = m{^
			(c\d+)\s+   # Controller
			(\S+)\s+    # Model
			(\d+)\s+    # (V)Ports
			(\d+)\s+    # Drives
			(\d+)\s+    # Units
			(\d+)\s+    # NotOpt: Not Optional
						# Not Optimal refers to any state except OK and VERIFYING.
						# Other states include INITIALIZING, INIT-PAUSED,
						# REBUILDING, REBUILD-PAUSED, DEGRADED, MIGRATING,
						# MIGRATE-PAUSED, RECOVERY, INOPERABLE, and UNKNOWN.
			(\d+)\s+    # RRate: Rebuild Rate
			(\d+|-)\s+  # VRate: Verify Rate
			(\S+|-)?    # BBU
		}x) {
			$c{$ctl} = {
				model => $model,
				ports => int($ports),
				drives => int($drives),
				units => int($units),
				optimal => int(!$notopt),
				rrate => int($rrate),
				vrate => to_i($vrate),
				bbu => $bbu,
			};
		}
	}
	close $fh;

	# no controllers? skip early
	return unless %c;

	for my $c (keys %c) {
		# get each unit on controllers
		$fh = $this->cmd('unitstatus', { '$controller' => $c });
		while (<$fh>) {
			if (my($u, $type, $status, $p_rebuild, $p_vim, $strip, $size, $cache, $avrify) = m{^
				(u\d+)\s+ # Unit
				(\S+)\s+  # UnitType
				(\S+)\s+  # Status
				(\S+)\s+  # %RCmpl: The %RCompl reports the percent completion
						  # of the unit's Rebuild, if this task is in progress.
				(\S+)\s+  # %V/I/M: The %V/I/M reports the percent completion
						  # of the unit's Verify, Initialize, or Migrate,
						  # if one of these are in progress.
				(\S+)\s+  # Strip
				(\S+)\s+  # Size(GB)
				(\S+)\s+  # Cache
				(\S+)     # AVrify
			}x) {
				$c{$c}{unitstatus}{$u} = {
					type => $type,
					status => $status,
					rebuild_percent => $p_rebuild,
					vim_percent => $p_vim,
					strip => $strip,
					size => $size,
					cache => $cache,
					avrify => $avrify,
				};
				next;
			}

			if (m{^u\d+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}
		}
		close $fh;

		# get individual disk status
		$fh = $this->cmd('drivestatus', { '$controller' => $c });
		# common regexp
		my $r = qr{^
			(p\d+)\s+       # Port
			(\S+)\s+        # Status
			(\S+)\s+        # Unit
			([\d.]+\s[TG]B|-)\s+ # Size
		}x;

		while (<$fh>) {
			# skip empty line
			next if /^$/;

			# Detect version
			if (/^Port/) {
				# <=9.5.1: Blocks Serial
				$r .= qr{
					(\S+)\s+  # Blocks
					(.+)      # Serial
				}x;
				next;
			} elsif (/^VPort/) {
				# >=9.5.2: Type Phy Encl-Slot Model
				$r .= qr{
					(\S+)\s+ # Type
					(\S+)\s+ # Phy
					(\S+)\s+ # Encl-Slot
					(.+)     # Model
				}x;
				next;
			}

			if (my($port, $status, $unit, $size, @rest) = ($_ =~ $r)) {
				# do not report disks not present
				# tw_cli 9.5.2 and above do not list these at all
				next if $status eq 'NOT-PRESENT';
				my %p;

				if (@rest <= 2) {
					my ($blocks, $serial) = @rest;
					%p = (
						blocks => to_i($blocks),
						serial => trim($serial),
					);
				} else {
					my ($type, $phy, $encl, $model) = @rest;
					%p = (
						type => $type,
						phy => to_i($phy),
						encl => $encl,
						model => $model,
					);
				}

				$c{$c}{drivestatus}{$port} = {
					status => $status,
					unit => $unit,
					size => $size,
					%p,
				};

				next;
			}

			if (m{^p\d+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}
		}
		close $fh;
	}

	return \%c;
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $c = $this->parse;
	if (!$c) {
		$this->unknown;
		$this->message("No Adapters were found on this machine");
	}

	# process each controller
	for my $cid (sort keys %$c) {
		my $c = $c->{$cid};
		my @cstatus;

		for my $uid (sort keys %{$c->{unitstatus}}) {
			my $u = $c->{unitstatus}->{$uid};
			my $s = $u->{status};

			if ($s =~ /INITIALIZING|MIGRATING/) {
				$this->warning;
				$s .= " $u->{vim_percent}";

			} elsif ($s eq 'VERIFYING') {
				$this->check_status;
				$s .= " $u->{vim_percent}";

			} elsif ($s eq 'REBUILDING') {
				$this->resync;
				$s .= " $u->{rebuild_percent}";

			} elsif ($s eq 'DEGRADED') {
				$this->critical;

			} elsif ($s ne 'OK') {
				$this->critical;

			}

			my @ustatus = $s;

			# report cache, no checking
			if ($u->{cache} && $u->{cache} ne '-') {
				push(@ustatus, "Cache:$u->{cache}");
			}

			push(@status, "$cid($c->{model}): $uid($u->{type}): ".join(', ', @ustatus));
		}

		# check individual disk status
		my %ds;
		foreach my $p (sort { $a cmp $b } keys %{$c->{drivestatus}}) {
			my $d = $c->{drivestatus}->{$p};
			my $ds = $d->{status};
			if ($ds eq 'VERIFYING') {
				$this->check_status;
			} elsif ($ds ne 'OK') {
				$this->critical;
			}

			if ($d->{unit} eq '-') {
				$ds = 'SPARE';
			}

			push(@{$ds{$ds}}, $p);
		}
		push(@status, "Drives($c->{drives}): ".$this->join_status(\%ds)) if %ds;

		# check BBU
		if ($this->bbu_monitoring && $c->{bbu} && $c->{bbu} ne '-') {
			$this->critical if $c->{bbu} ne 'OK';
			push(@status, "BBU: $c->{bbu}");
		}
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
