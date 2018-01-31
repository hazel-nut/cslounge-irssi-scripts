use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
    authors     => 'Hazel Virdó <github@virdo.name>',
    name        => 'away_from_screen',
    description => 'set away status based on screen attached/detached',
    license     => 'CC BY-SA 4.0',
    url         => 'https://github.com/hazel-nut/cslounge-irssi-scripts',
);

if (!defined($ENV{STY})) { # not running in screen
	return;
}

# socket path code + screen_attached() taken from irssinotifier
# https://github.com/murgo/IrssiNotifier/blob/master/Irssi/irssinotifier.pl

my $screen_socket_path;
my $screen_ls = `LC_ALL="C" screen -ls 2> /dev/null`;
if ($screen_ls !~ /^No Sockets found/s) {
	$screen_ls =~ /Sockets? in (.+)\./s; # but this regex is different
	$screen_socket_path = $1;
} else {
	$screen_ls =~ /^No Sockets found in ([^\n]+)\.\n.+$/s;
	$screen_socket_path = $1;
}

sub screen_attached {
    if (!$screen_socket_path || !defined($ENV{STY})) {
        return 0;
    }
    my $socket = $screen_socket_path . "/" . $ENV{'STY'};
    if (-e $socket && ((stat($socket))[2] & 00100) != 0) {
        return 1;
    }
    return 0;
}

sub set_away_from_screen {
	my ($server);
	foreach $server (Irssi::servers()) {
		if (screen_attached() && $server->{usermode_away}) {
			$server->command('AWAY');
		} elsif (!screen_attached() && !$server->{usermode_away}) {
			$server->command('AWAY ' . Irssi::settings_get_str($IRSSI{'name'} . '_message'));
		}
	}
}

Irssi::settings_add_str('misc', $IRSSI{'name'} . '_message', "not here ...");
Irssi::timeout_add(5000, 'set_away_from_screen', ''); # TODO: custom timeouts (meh)
