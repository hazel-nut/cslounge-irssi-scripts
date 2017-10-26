use strict;
use Data::Dumper;
use warnings;
use vars  qw ($VERSION %IRSSI);
use POSIX qw(strftime);
use Irssi 20020325 qw (command_bind command_runsub command timeout_add_once timeout_remove signal_add_first);

$VERSION = '0.1';
%IRSSI = (
    authors     => 'hazelnut',
    contact     => 'irssiscripts@virdo.name' ,
    name        => 'reminder',
    description => 'gloms reminders into highlightwin. this is bad and cargo culted together. use at your own risk.',
    license     => 'Public Domain',
    changed     => '2017-10-26'
);

our %timers;

sub remind {
    my ( $text ) = @_;
    my ( $window ) = Irssi::window_find_name('hilight');
    $window->print("%6[reminder]%N It's been %C$timers{$text}->{'duration'}%N since %C$text%N was started at $timers{$text}->{'started'}.", MSGLEVEL_NEVER) if ($window);
    command('beep');
    cmd_remove_timer($text); 
}

sub cmd_remove_timer {
    my ( $text ) = @_;
    if ( exists ( $timers{$text} ) ) {
        timeout_remove($timers{$text}->{'timer'});
        $timers{$text} = ();
        delete ( $timers{$text} );
        return 1;
    }
    return 0;
}

sub cmd_remind_help {
    print ( <<EOF

Usage:
    /remind add <time: \\d+[smh]> <reminder text>
    /remind add <reminder text> <time: \\d+[smh]>
    /remind nvm <reminder text>
    /remind list
EOF
    );
}

sub parse_time {
    # this is really bad lol.
    my ( $time ) = @_;
    my ( $time_duration ) = substr($time, 0, -1);
    my ( $time_units ) = substr($time, -1, 1);
    
    if ( $time_units eq "s") {
        return $time_duration * 1000; # seconds
    } elsif ( $time_units eq "m" ) {
        return $time_duration * 60 * 1000; # minutes
    } elsif ( $time_units eq "h" ) {
        return $time_duration * 60 * 60 * 1000; #hours
    } else {
        return 0;
    };
}

command_bind 'remind add' => sub {
    my ( $data, $server, $item ) = @_;

    my ( $duration, $text );
    if ( $data =~ /^\s*(\d+[smh])\s+(.*)\s*$/ ) {
        ( $duration, $text ) = ( $1, $2 );
    } elsif ( $data =~ /^\s*(.*)\s+(\d+[smh])\s*$/ ) {
        ( $duration, $text ) = ( $2, $1 );
    } elsif ( $data =~ /^\s*(\d+[smh])\s*$/ ) {
        ( $duration, $text ) = ( $1, "something-" . time);
    } else {
        print( CRAP "Reminder parameters not understood: $data");
        command('beep');
        return;
    };

    if ( exists ( $timers{$text} ) ) {
        print( CRAP "A reminder for \"$text\" is already active." );
        command('beep');
        return;
    };

    # convert time to milliseconds for timeout_add_once()
    my ( $millisec ) = parse_time($duration);
    if ( $millisec == 0) {
        print( CRAP "Reminder duration not understood: $duration" );
        print( CRAP "Supported durations: s (second), m (minute), h (hour). Default is seconds." );
        command('beep');
        return;
    };

    print( CRAP "In $duration, I'll remind you: $text" );
    $timers{$text}->{'duration'} = $duration;
    $timers{$text}->{'timer'} = timeout_add_once( $millisec, \&remind, $text );
    $timers{$text}->{'started'} = strftime "%H:%M:%S", localtime;
};

command_bind 'remind list' => sub {
    if (%timers) {
        print( CRAP "Active reminders:" );
        foreach my $text ( keys %timers ) {
            print( CRAP "  $timers{$text}->{'duration'} after $timers{$text}->{'started'}, $text");
        }
    } else {
        print( CRAP "No active reminders.");
    }
};

command_bind 'remind nvm' => sub {
    my ( $text, $server, $item ) = @_;
    my ( $removed ) = cmd_remove_timer($text);
    
    if ( $text eq "" ) {
        print( CRAP "Which reminder do you want me to remove?" );
    } elsif ( $removed == 0 ) {
        print( CRAP "No such reminder: $text." );
    } else {
        print( CRAP "Removed reminder: $text." );
    }
};

command_bind 'remind help' => sub {
    cmd_remind_help()
};

command_bind 'remind' => sub {
    my ( $data, $server, $item ) = @_;
    $data =~ s/\s+$//g;
    my $result = command_runsub ('remind', $data, $server, $item ) ;
};

# gets triggered if called with unknown subcommand
signal_add_first 'default command remind' => sub {
    cmd_remind_help()
};

my $window = Irssi::window_find_name('hilight');
Irssi::print("Create a window named 'hilight'; this script abuses it") if (!$window)
