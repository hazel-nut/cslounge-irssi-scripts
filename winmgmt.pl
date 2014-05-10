# 
# winmgmt.pl - tools to manage windows in gwillen's preferred fashion
#
# Currently provides the following commands:
#
# ssave:
# - adds all joined channels to the saved channels list with /channel add
# - does /layout save to save all their window numbers
# - does /save to commit your config
#
# cleanup:
# - destroys all windows with no contents
#
# clearhilight:
# - dehilights all windows
#
# Glenn Willen (gwillen@nerdnet.org)

=head1 AUTHORS

For getchan.pl:
- Copyright E<copy> 2011 Tom Feist C<E<lt>shabble+irssi@metavore.orgE<gt>>

For everything else:
- Glenn Willen dedicates everything else into the public domain.

=head1 LICENCE

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=cut 

use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

use POSIX;
use Data::Dumper;
use vars qw($VERSION %IRSSI); 

$VERSION = "0.01";
%IRSSI = (
    authors     => "Glenn Willen",
    contact     => "gwillen\@nerdnet.org",
    name        => "winmgmt",
    description => "Tools to manage windows in gwillen's preferred fashion",
    license     => "MIT",  # Required by getchan 
    url         => "http://irssi.org/",
    changed     => "Tue Feb 8 00:00:00 EST 2011"
);

my $line_format;
my $head_format;
my $foot_format;

my $channels = {};
my @errors;
my $state;

sub get_format_string {
    return Irssi::current_theme->get_format(@_);
}

sub get_channels {
    $channels = {};

    # see here: https://github.com/shabble/irssi-docs/wiki/complete_themes
    $line_format = get_format_string('fe-common/core', 'chansetup_line');
    $head_format = get_format_string('fe-common/core', 'chansetup_header');
    $foot_format = get_format_string('fe-common/core', 'chansetup_footer');

    my $parse_line_format = "channel:\$0\tnet:\$1\tpass:\$2\tsettings:\$3";
    Irssi::command("^FORMAT chansetup_line $parse_line_format");
    Irssi::command("^FORMAT chansetup_header START");
    Irssi::command("^FORMAT chansetup_footer END");

    $state = 0;
    Irssi::signal_add_first('print text', 'sig_print_text');
    Irssi::command("CHANNEL LIST");
    Irssi::signal_remove('print text', 'sig_print_text');

}

sub restore_formats {
    Irssi::command("^FORMAT chansetup_line $line_format");
    Irssi::command("^FORMAT chansetup_header $head_format");
    if ($foot_format =~ m/^\s*$/) {
        Irssi::command("^FORMAT -delete chansetup_footer");
    } else {
        Irssi::command("^FORMAT  chansetup_footer $foot_format");
    }
}

sub sig_print_text {
    my ($dest, $text, $stripped) = @_;

    my $entry = {};

    if ($state == 0 && $text =~ m/START/) {
        $state = 1;
    } elsif ($state == 1) {
        # TODO: might we get multiple lines at once?
        if ($text =~ m/channel:([^\t]+)\tnet:([^\t]+)\tpass:([^\t]*)\tsettings:(.*)$/) {
            $entry->{channel}  = $1;
            $entry->{network}  = $2;
            $entry->{password} = $3;
            $entry->{settings} = $4;

            my $tag = "$2/$1";
            $channels->{$tag} = $entry;

        } elsif ($text =~ m/END/) {
            $state = 0;
        } else {
            push @errors, "Failed to parse: '$text'";
        }
    }
    Irssi::signal_stop();
}

sub get_all_channels {
    eval {
        get_channels();
    };
    if ($@) {
        print "Error: $@. Reloading theme to restore format";
        Irssi::themes_reload();
    } else {
        restore_formats();
    }
    if (@errors) {
        @errors = map { s/\t/    /g } @errors;
        print Dumper(\@errors);
    }
    return $channels;
}

sub cmd_clearhilight {
  my ($data, $server, $witem) = @_;
  if ($data ne "") {
    Irssi::print("No argument permitted to clearhilight. (Usage: run without arguments to clear all hilights.)");
    return;
  }
  my $saved = Irssi::active_win()->{refnum};
  my @wins = Irssi::windows();
  foreach my $win (@wins) {
    if (!exists $win->{refnum}) {
      print "MISSING REFNUM";
      next;
    }
    if ($win->{data_level}) {
      Irssi::command("win $win->{refnum}");
    }
  }
  Irssi::command("win $saved");
}

sub cmd_cleanup {
  my ($data, $server, $witem) = @_;
  if ($data ne "") {
    Irssi::print("No argument permitted to cleanup. (Usage: run without arguments to destroy all empty windows.)");
    return;
  }

  print "Cleaning up empty windows...";
  my @wins = Irssi::windows();
  foreach my $win (@wins) {
    if (!exists $win->{refnum}) {
      print "MISSING REFNUM?!";
      next;
    }

    if (!$win->{name} && !exists($win->{active})) {
      print "Destroying window $win->{refnum}";
      $win->destroy();
    }
  }
  print "Done.";
}

sub cmd_ssave {
  my ($data, $server, $witem) = @_;
  if ($data ne "") {
    Irssi::print("No argument permitted to ssave. (Usage: run without arguments to add all joined channels to the list of saved channels, and /layout save, and /save.)");
    return;
  }

  print "Saving servers...";
  my @servers = Irssi::servers();
  if (scalar @servers == 0) {
     print "Something's wrong; no servers! Not saving.";
     return;
  }
  foreach my $server (@servers) {
    my $net = "";
    if ($server->{'chatnet'}) {
      $net = $server->{'chatnet'};
    } elsif ($server->{'tag'}) {
      $net = $server->{'tag'};
    } else {
      $net = $server->{'address'};
      # But really, don't do that. I don't think this can even happen.
    }
    Irssi::command("network add $net");
    Irssi::command("server add -auto -network $net $server->{address} $server->{port}");
  }

  my $remove_channels = get_all_channels();

  print "Saving channels...";
  my @chans = Irssi::channels();
  if (scalar @chans == 0) {
    print "Something's wrong; no channels! Not saving.";
    return;
  }
  foreach my $chan (@chans) {
    my $net = "";
    if ($chan->{'server'}->{'chatnet'}) {
      $net = $chan->{'server'}->{'chatnet'};
    } elsif ($chan->{'server'}->{'tag'}) {
      $net = $chan->{'server'}->{'tag'};
    } else {
      $net = $chan->{'server'}->{'address'};
      # Same caveat as above.
    }

    delete $remove_channels->{"$net/$chan->{'name'}"};
    Irssi::command("channel add -auto $chan->{name} $net $chan->{key}");
  }

  Irssi::command("layout save");
  Irssi::command("save");

  if (keys %$remove_channels) {
    print "You have the following channels saved, but are not in them:";
    foreach my $k (keys %$remove_channels) {
      print $k;
    }
    printf "If you want to remove these channels from your saved set, /clearchannels.";
  }
}

sub cmd_clearchannels {
  my ($data, $server, $witem) = @_;
  if ($data ne "") {
    Irssi::print("No argument permitted to clearchannels. (Usage: run without arguments to remove all non-joined channels from the list of saved channels. Does not save anything permanently until you /save.)");
    return;
  }

  my $remove_channels = get_all_channels();

  my @chans = Irssi::channels();
  if (scalar @chans == 0) {
    print "Something's wrong; no channels! Not going to nuke everything.";
    return;
  }
  foreach my $chan (@chans) {
    my $net = "";
    if ($chan->{'server'}->{'chatnet'}) {
      $net = $chan->{'server'}->{'chatnet'};
    } elsif ($chan->{'server'}->{'tag'}) {
      $net = $chan->{'server'}->{'tag'};
    } else {
      $net = $chan->{'server'}->{'address'};
      # Same caveat as above.
    }

    delete $remove_channels->{"$net/$chan->{'name'}"};
  }

  if (keys %$remove_channels) {
    print "The following channels will be removed the next time you /save:";
    foreach my $c (values %$remove_channels) {
      Irssi::command("channel remove $c->{'channel'} $c->{'network'}");
    }
    printf "To permanently remove these channels from your saved set, /save now.";
  } else {
    print "No channels to remove.";
  }
}

Irssi::command_bind('clearhilight', 'cmd_clearhilight');
Irssi::command_bind('cleanup', 'cmd_cleanup');
Irssi::command_bind('ssave', 'cmd_ssave');
Irssi::command_bind('clearchannels', 'cmd_clearchannels');

# vim:set ts=4 sw=4 et:
