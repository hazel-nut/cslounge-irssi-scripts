#!/usr/bin/perl -w

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
use Encode;

$VERSION = "1.00";
%IRSSI = (
	authors => 'elly, rbraun',
	name => '',
	description => 'Rainbow text for the 2014 World Cup teams',
	license => 'Public Domain',
	changed => '2014-06-13',
);

sub rainbowize {
my %cflags = (
	# Group A
	brazil => [9, 8, 12],
	mexico => [9, 0, 4],
	cameroon => [3, 4, 8],
	croatia => [4, 0, 2],

	# Group B
	netherlands => [4, 0, 12],
	holland => [4, 0, 12],
	australia => [12, 12, 12, 0, 4, 0],
	chile => [12, 0, 4, 4],
	spain => [4, 8, 8, 4],

	# Group C
	colombia => [8, 8, 12, 4],
	cotedivoire => [4, 0, 9],
	greece => [12, 0],
	japan => [0, 0, 4, 4],

	# Group D
	costarica => [2, 15, 4, 4, 15, 2],
	england => [0, 4],
	italy => [9, 0, 4],
	uruguay => [0, 12, 8],

	# Group E
	ecuador => [8, 8, 12, 4],
	france => [12, 0, 4],
	honduras => [12, 0, 12],
	switzerland => [5, 5, 0],

	# Group F
	argentina => [11, 11, 0, 8, 0, 11, 11],
	bosnia => [12, 8, 0],
	iran => [9, 0, 0, 4],
	nigeria => [9, 0, 9], # sadly not 4, 1, 9

	# Group G
	germany => [14, 4, 8],
	ghana => [4, 8, 3],
	portugal => [3, 3, 8, 4, 4, 4],
	unitedstates => [4, 0, 12],
	usa => [4, 0, 12],
	america => [4, 0, 12],

	# Group H
	algeria => [9, 9, 5, 0, 0],
	belgium => [14, 8, 4],
	korea => [0, 4, 12, 14],
	southkorea => [0, 4, 12, 14],
	russia => [0, 12, 4],
);

	my ($t) = @_;
	my ($country) = split(/  */, $t);
	$t =~ s/^[^ ]* *//;
	my @p = split(//,$t);
	my $k = 0;
	my $cref = $cflags{$country};
	my @colors = @$cref;
	my @colorstr = map { sprintf('%02d', $_) } @colors;
	foreach my $q (@p) {
		if ($q ne " ") {
			$q = "\x03" . $colorstr[$k++ % @colorstr] . $q;
		}
	}
	return join('',@p);
}

sub cmd_wcupbow {
	eval {
		my ($t,$s,$w) = @_;
		$t = decode('UTF-8',$t);
		my $r = rainbowize($t);
		if ($w && ($w->{type} eq 'CHANNEL' or $w->{type} eq 'QUERY')) {
			$w->command("MSG " . $w->{name} . " " . $r);
		}
		return;
	};

	if ($@) {
		my $erc = $@;
		$erc =~ s/\n*$//;
		Irssi::print("Oh no, something went wrong! $erc");
	}
}

Irssi::command_bind('worldcup', 'cmd_wcupbow');

