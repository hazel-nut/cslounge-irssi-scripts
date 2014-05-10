#!/usr/bin/perl -w

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
use Encode;

$VERSION = "2.00";
%IRSSI = (
	authors => 'elly',
	name => 'rainbow',
	description => 'Rainbow text',
	license => 'Public Domain',
	changed => 'Never',
);

sub rainbowize {
	my ($t) = @_;
	my @p = split(//,$t);
	my $k = 0;
	my @colors = (4, 8, 9, 11, 12, 13);
	foreach my $q (@p) {
		if ($q =~ /\S/) {
			$q = sprintf("\x03%02i%s", $colors[$k++ % @colors], $q);
		}
	}
	return join('',@p);
}

sub cmd_rainbow {
	my ($t,$s,$w) = @_;
	$t = decode('UTF-8',$t);
	my $r = rainbowize($t);
	if ($w && ($w->{type} eq 'CHANNEL' or $w->{type} eq 'QUERY')) {
		$w->command("MSG " . $w->{name} . " " . $r);
	}
}

sub cmd_texrainbow {
        my ($t,$s,$w) = @_;
        $t = decode('UTF-8',$t);
	$t =~ s/\\rainbow\{(.*?)\}/rainbowize($1) . "\x0f"/eg;
        if ($w && ($w->{type} eq 'CHANNEL' or $w->{type} eq 'QUERY')) {
                $w->command("MSG " . $w->{name} . " " . $t);
        }
}

Irssi::command_bind('rainbow', 'cmd_rainbow');
Irssi::command_bind('texrb', 'cmd_texrainbow');
