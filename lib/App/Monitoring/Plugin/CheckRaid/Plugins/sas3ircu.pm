package App::Monitoring::Plugin::CheckRaid::Plugins::sas3ircu;

# Avago SAS-3 controllers using the SAS-3 Integrated RAID Configuration Utility (SAS3IRCU)
# Based on the SAS-3 Integrated RAID Configuration Utility (SAS3IRCU) User Guide
# https://docs.broadcom.com/doc/12353382

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'controller list' => ['-|', '@CMD', 'LIST'],
		'controller status' => ['-|', '@CMD', '$controller', 'STATUS'],
		'device status' => ['-|', '@CMD', '$controller', 'DISPLAY'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd LIST",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd * STATUS",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd * DISPLAY",
	);
}

# detect controllers for sas3ircu
sub detect {
	my $this = shift;

	my @ctrls;
	my $fh = $this->cmd('controller list');

	my $success = 0;
	my $state="";
	my $noctrlstate="No Controllers";
	while (<$fh>) {
		chomp;

		#         Adapter     Vendor  Device                        SubSys  SubSys
		# Index    Type          ID      ID    Pci Address          Ven ID  Dev ID
		# -----  ------------  ------  ------  -----------------    ------  ------
		#   0     SAS3008       1000h   97h    00h:02h:00h:00h      1458h   3008h
		if (my($c) = /^\s*(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s*$/) {
			push(@ctrls, $c);
		}
		$success = 1 if /SAS3IRCU: Utility Completed Successfully/;

		# handle the case where there's no hardware present.
		# when there is no controller, we get
		# root@i41:/tmp$ /usr/sbin/sas3ircudsr LIST
		# Avago Technologies SAS3 IR Configuration Utility.
		# Version 17.00.00.00 (2018.04.02)
		# Copyright (c) 2009-2018 Avago Technologies. All rights reserved.
                #
		# SAS3IRCU: MPTLib2 Error 1
		# root@i41:/tmp$ echo $?
		# 1

		if (/SAS3IRCU: MPTLib2 Error 1/) {
			$state = $noctrlstate;
			$success = 1 ;
		}

	}

	unless (close $fh) {
		#sas3ircu exits 1 (but close exits 256) when we close fh if we have no controller, so handle that, too
		if ($? != 256 && $state eq $noctrlstate) {
			$this->critical;
		}
	}
	unless ($success) {
		$this->critical;
	}

	return wantarray ? @ctrls : \@ctrls;
}

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };
sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };

sub check {
	my $this = shift;

	my @ctrls = $this->detect;

	my @status;
	my $numvols=0;
	# determine the RAID states of each controller
	foreach my $c (@ctrls) {
		my $fh = $this->cmd('controller status', { '$controller' => $c });

		my $novolsstate="No Volumes";
		my $state;
		my $success = 0;
		while (<$fh>) {
			chomp;

			# match adapter lines
			if (my($s) = /^\s*Volume state\s*:\s*(\w+)\s*$/) {
				$state = $s;
				$numvols++;
				if ($state ne "Optimal") {
					$this->critical;
				}
			}
			$success = 1 if /SAS3IRCU: Utility Completed Successfully/;

			##handle the case where there are no volumes configured
			#
			# SAS3IRCU: there are no IR volumes on the controller!
			# SAS3IRCU: Error executing command STATUS.

			if (/SAS3IRCU: there are no IR volumes on the controller/
				or /The STATUS command is not supported by the firmware currently loaded on controller/
			) {
				# even though this isn't the last line, go ahead and set success.
				$success = 1;
				$state = $novolsstate;
			}

		}

		unless (close $fh) {
			#sas3ircu exits 256 when we close fh if we have no volumes, so handle that, too
			if ($? != 256 && $state eq $novolsstate) {
				$this->critical;
				$state = $!;
			}
		}

		unless ($success) {
			$this->critical;
			$state = "SAS3IRCU Unknown exit";
		}

		unless ($state) {
			$state = "Unknown Error";
		}

		my $finalvolstate=$state;
		#push(@status, "ctrl #$c: $numvols Vols: $state");


		#####  now look at the devices.
                # Device is a Hard disk
                #   Enclosure #                             : 1
                #   Slot #                                  : 0
                #   SAS Address                             : 4433221-1-0200-0000
                #   State                                   : Optimal (OPT)
                #   Size (in MB)/(in sectors)               : 3662830/7501476527
                #   Manufacturer                            : ATA     
                #   Model Number                            : SAMSUNG MZ7L33T8
                #   Firmware Revision                       : 004Q
                #   Serial No                               : S6EMNE0RB00766
                #   Unit Serial No(VPD)                     : S6EMNE0RB00766
                #   GUID                                    : 5002538f01b17289
                #   Protocol                                : SATA
                #   Drive Type                              : SATA_SSD

		$fh = $this->cmd('device status', { '$controller' => $c });
		$state="";
		$success = 0;
		my $enc="";
		my $slot="";
		my @data;
		my $device="";
		my $numslots=0;
		my $finalstate;
		my $finalerrors="";

		while (my $line = <$fh>) {
			chomp $line;
			# Device is a Hard disk
			# Device is a Hard disk
			# Device is a Enclosure services device
			#
			#lets make sure we're only checking disks.  we dont support other devices right now
			if ("$line" eq 'Device is a Hard disk') {
				$device='disk';
			} elsif ($line =~ /^Device/) {
				$device='other';
			}

			if ("$device" eq 'disk') {
				if ($line =~ /Enclosure #|Slot #|State /) {
					#find our enclosure #
					if ($line =~ /^  Enclosure # /) {
						@data = split /:/, $line;
						$enc=trim($data[1]);
						#every time we hit a new enclosure line, reset our state and slot
						undef $state;
						undef $slot;
					}
					#find our slot #
					if ($line =~ /^  Slot # /) {
						@data = split /:/, $line;
						$slot=trim($data[1]);
						$numslots++
					}
					#find our state
					if ($line =~ /^  State /) {
						@data = split /:/, $line;
						$state=ltrim($data[1]);

						#for test
						#if ($numslots == 10 ) { $state='FREDFISH';}

						#when we get a state, test on it and report it..
						if ($state =~ /Optimal|Ready/) {
							#do nothing at the moment.
						} else {
							$this->critical;
							$finalstate=$state;
							$finalerrors="$finalerrors ERROR:Ctrl$c:Enc$enc:Slot$slot:$state";
						}
					}
				}
			}

			if ($line =~ /SAS3IRCU: Utility Completed Successfully/) {
				$success = 1;
			}

		} #end while


		unless (close $fh) {
			$this->critical;
			$state = $!;
		}

		unless ($success) {
			$this->critical;
			$state = "SAS3IRCU Unknown exit";
		}

		unless ($state) {
			$state = "Unknown Error";
		}

		unless($finalstate) {
			$finalstate=$state;
		}

		#per controller overall report
		#push(@status, ":$numslots Drives:$finalstate:$finalerrors");
		push(@status, "ctrl #$c: $numvols Vols: $finalvolstate: $numslots Drives: $finalstate:$finalerrors:");

	}

	##if we didn't get a status out of the controllers and an empty ctrls array, we must not have any.
	unless (@status && @ctrls) {
		push(@status, "No Controllers");
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
