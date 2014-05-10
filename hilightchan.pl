#
# Hilights messages from specific channels
# Glenn Willen (gwillen@nerdnet.org)
# Based on hilightwin.pl by Timo Sirainen

use Irssi;
use POSIX;
use vars qw($VERSION %IRSSI); 

$VERSION = "0.01";
%IRSSI = (
    authors     => "Glenn Willen",
    contact     => "gwillen\@nerdnet.org",
    name        => "hilightchan",
    description => "Hilight all messages from selected channels",
    license     => "Public Domain",
    url         => "http://irssi.org/",
    changed     => "Tue Oct 13 14:19:26 EST 2009"
);
our $fuckoff = 0;

sub sig_msgpublic {
    my ($server, $msg, $nick, $address, $target) = @_;

    if ($target eq "#gwillen-test") {
      #Irssi::print("Got a live one");

    }
}

sub sig_printtext {
    my ($dest, $text, $stripped) = @_;
    return if $fuckoff;
    my $channels = Irssi::settings_get_str('hilight_channels');
    my @channels = split(" ", $channels);
    my %channels = ();
    map { $channels{$_} = 1; } @channels;

    #$fuckoff = 1;
    #Irssi::print("$dest->{target}: hilightchan ($dest->{level})");
    #$fuckoff = 0;
    if($channels{$dest->{target}} && (
         $dest->{level} & MSGLEVEL_PUBLIC ||
         $dest->{level} & MSGLEVEL_ACTIONS ||
         $dest->{level} & MSGLEVEL_NOTICES ||
         $dest->{level} & MSGLEVEL_JOINS)) {
        my $windowitem = Irssi::window_item_find($dest->{target});
        my $msglevel = MSGLEVEL_HILIGHT | $dest->{level};
        #Irssi::signal_continue($dest, $text, $stripped);
        #Irssi::print("$dest->{target}: hilightchan becomes ($dest->{level})");
        if (defined $windowitem) {
          local $fuckoff = 1;
          Irssi::signal_stop();
          #Irssi::signal_emit('print text', $dest, $text, $stripped);
          #$window->print($text, $dest->{level} | MSGLEVEL_HILIGHT);
          $windowitem->print("$text", $msglevel);
        }
        #Irssi::print("hilightchan: right channel");
        #Irssi::print("hilightchan: did a thing");
    } else {
      local $fuckoff = 1;
      #Irssi::print "failed: $text";
    }
}

#    my $opt = MSGLEVEL_HILIGHT;
#
#    if(Irssi::settings_get_bool('hilightwin_showprivmsg')) {
#        $opt = MSGLEVEL_HILIGHT|MSGLEVEL_MSGS;
#    }
#    
#    if(
#        ($dest->{level} & ($opt)) &&
#        ($dest->{level} & MSGLEVEL_NOHILIGHT) == 0
#    ) {
#        $window = Irssi::window_find_name('hilight');
#        
#        if ($dest->{level} & MSGLEVEL_PUBLIC) {
#            $text = $dest->{target}.": ".$text;
#        }
#        $text = strftime(
#            Irssi::settings_get_str('timestamp_format')." ",
#            localtime
#        ).$text;
#        $window->print($text, MSGLEVEL_NEVER) if ($window);
#    }
#}
#
#$window = Irssi::window_find_name('hilight');
Irssi::print("Hilightchan.pl coming to an irssi near you!");

Irssi::settings_add_str('hilightchan','hilight_channels',1);

Irssi::signal_add_first('print text', 'sig_printtext');
#Irssi::signal_add('message public', 'sig_msgpublic');

# vim:set ts=4 sw=4 et:
