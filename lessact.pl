#!/usr/bin/perl -w
# less activity magic

#<scriptinfo>
use vars qw($VERSION %IRSSI);

use Irssi 20020120;
$VERSION = "0.2";
%IRSSI = (
	authors => "Rodney Dawes",
	contact => "dobey@gnome.org",
	name => "Only show high level activity changes",
	description => "Ignores low level activity status",
	license => "Public Domain",
	url => "http://wayofthemonkey.com/lessact.pl",
	changed => "Fri Jan 02 14:20:00 EST 2009",
);
#</scriptinfo>

my %line=();

# Doesn't show activity change for certain messages.
# List as many as ya want.
my @ignores = (
	'^MSG #channel nick regex_matching_message'
    );

sub window_activity() {
    my ($item, $oldstatus) = @_;

    my $level = $item->{data_level};
		my $chan = $item->{active}->{name};

    return if ($level <= $oldstatus);

		foreach my $ignore (@ignores)
		{
			if($line->{$chan}=~/($ignore)/)
			{
				Irssi::signal_emit("window dehilight", $item);
			}
		}
		
    Irssi::signal_emit("window dehilight", $item) if ($level < 2)
}

sub sig_public {
	my ($server, $msg, $nick, $address, $target) = @_;
	
	$line->{$target}="MSG $target $nick $msg";
}

sub sig_public_act {
	my ($server, $msg, $nick, $address, $target) = @_;
	
	$line->{$target}="ACT $target $nick $msg";
}


Irssi::signal_add_first("window activity", \&window_activity);

Irssi::signal_add_first("message public", 'sig_public');
Irssi::signal_add_first("message irc action", 'sig_public');
