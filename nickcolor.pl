# A hacked version of the standard nickcolor.pl.
#
# The "vanilla" nickcolor would hash each nick to choose a color,
# essentially randomly coloring the names. This version tries to be a
# bit smarter: it uses a few criteria to try to decide on a
# color. When someone first starts talking, it will try to choose a
# color that's not in use by anyone else actively talking; if that
# fails, it will try to collide with a name that's not easily-confused
# with the one to which we're assigning a color. We also allow a name
# to be re-colored, but only if that person hasn't talked for a long
# time.
#
# In addition, you can issue the command
#		 /recolor <nick>
# to change the color of nick to whatever the script feels is
# best. Use this if a lot of people actively talking have the same
# color. You can also say
#		 /recolor -all
# to entirely reset the colors.
#
# The script also supports colouring nicks within text. The
# "colorlevel" variable controls this. The settings are:
#
# 0: no colouring.
# 1: just colour names of people talking (the usual behaviour)
# 2: also colour names of people being talked to (nick: text)
# 3: colour all nicknames that occur within all messages.
#    (A bug in irssi's built-in highlighter makes this interact poorly with
#     hilight -word. To fix this, apply this patch:
#       http://www.bswolf.com/irssi/nickcolor-hilight.patch
#     to src/fe-common/core/formats.c and recompile irssi.)
#
# The "nickcolor_global" variable enables colouring nicknames the same
# across all channels. It defaults to OFF (meaning the same user may have
# different colours in separate channels).
#
# -mrwright

# TODO:
#
# - Have a table of which colors are most similar to others (with
#		separate tables for various kinds of colorblindness), and take
#		that into account when assigning colors.
# - Also rank colors by how appealing they are in general, and give
#		those priority.
# - Clean up the code.

use strict;
use Irssi 20020101.0250 ();
use vars qw($VERSION %IRSSI); 
$VERSION = "1";
%IRSSI = (
          authors     => "Timo Sirainen, Ian Peters, Matthew Wright, bswolf",
          contact => "tss\@iki.fi", 
          name        => "Nick Color",
          description => "assign a different color for each nick",
          license => "Public Domain",
          url   => "http://irssi.org/",
          changed => "2013-11-27"
         );

# hm.. i should make it possible to use the existing one..
Irssi::theme_register([
                       'pubmsg_hilight', '{pubmsghinick $0 $3 $1}$2'
                      ]);

my %saved_colors;
my %session_colors = {};
my @colors = qw/2 3 4 5 6 7 9 10 11 12 13/;

my %last_talked = {};   # Store the time when each person last talked.
my %recolors = {};      # Nicks whose color we want changed.
my %recent_nicks_chan;  # Recent nicks, per-channel.

my $debuglev = 0;       # no debugging by default.
# Level 1 = basic messages
# Level 2 = print scoring every time someone talks
# Level 3 = all that and also print time penalty, and last talked list.

my $debug_to_file=1;

sub load_colors {
	# Different filename, since we use a different system.
	open COLORS, "$ENV{HOME}/.irssi/saved_colors_new";

	while (<COLORS>) {
		# I don't know why this is necessary only inside of irssi
		my @lines = split "\n";
		foreach my $line (@lines) {
			my($nick, $color) = split ":", $line;
			$saved_colors{$nick} = $color;
		}
	}

	close COLORS;
}

sub save_colors {
	# Different filename, since we use a different system.
	open COLORS, ">$ENV{HOME}/.irssi/saved_colors_new";

	foreach my $nick (keys %saved_colors) {
		print COLORS "$nick:$saved_colors{$nick}\n";
	}

	close COLORS;
}

sub debug {
	my $msg = shift;
	
	if ($debug_to_file) {
		open LOGFILE, ">>$ENV{HOME}/.irssi/nickcolor-new.log";
		print LOGFILE $msg . "\n";
		close LOGFILE;
	} else {
		Irssi::print $msg;
	}
}

# If someone we've colored (either through the saved colors, or the hash
# function) changes their nick, we'd like to keep the same color associated
# with them (but only in the session_colors, ie a temporary mapping).

sub sig_nick {
	my ($server, $newnick, $nick, $address) = @_;
	my $color;

	$newnick = substr ($newnick, 1) if ($newnick =~ /^:/);

	# Update the table of who talked recently.
	foreach my $channel (keys %recent_nicks_chan) {
		if ($color = $saved_colors{$nick}) {
			$session_colors{$channel}{$newnick} = $color;
		} elsif ($color = $session_colors{$channel}{$nick}) {
			$session_colors{$channel}{$newnick} = $color;
		}


		foreach my $name (@{$recent_nicks_chan{$channel}}) {
			if ($name eq $nick) {
				$name=$newnick;
			}
		}
		# Irssi::print("$channel: @{$recent_nicks_chan{$channel}}");
	}
}

sub best_color {
	my ($server, $msg, $nick, $address, $target) = @_;

	my $channel = $target;
	my $chanrec = $server->channel_find($target);
	return if not $chanrec;
	my $nickrec = $chanrec->nick_find($nick);
	return if not $nickrec;

	my %color_scores;

	if (Irssi::settings_get_bool('nickcolor_global') == 1) {
		# Yes, it's a horrible hack :)
		$channel = 'GLOBAL';
	}

	if (!$session_colors{$channel}) {
		$session_colors{$channel}={};
		debug("Created session colors.") if $debuglev > 0;
	}

	push(@{$recent_nicks_chan{$channel}},$nick);
	shift @{$recent_nicks_chan{$channel}}
		if (scalar(@{$recent_nicks_chan{$channel}})>=40);

	debug("@{$recent_nicks_chan{$channel}}") if $debuglev > 2;
	#Irssi::print("@recent_nicks");

	####################################################
	# Begin assigning scores.
	####################################################

	# Some of the scoring we do takes a bit longer, and we might
	# not want to do it every time. If this flag is unset, it means
	# that the extra work is unlikely to be worthwhile, probably because
	# some score has been set extremely high.
	my $worth_harder_tests=1;

	## If the user has set a color specifically, use it.

	# Has the user assigned this nick a color?
	my $color = $saved_colors{$nick};
	# If so, set it to an extremely high priority.
	$color_scores{$color} = 1000;
	$worth_harder_tests=0 if($color);

	my $recolored=0;
 
	# Did they ask that this nick be recolored?
	if ($recolors{$channel}{$nick}) {
		#Irssi::print("Recoloring $nick");
		$color_scores{$session_colors{$channel}{$nick}}=-10000;
		delete $recolors{$channel}{$nick};
		$recolored=1;
	}

	## Favour the user's existing color.

	my $lasttalked=$last_talked{$channel}{$nick};
	my $curtime = time();
	$last_talked{$channel}{$nick} = $curtime;

	# Hack to avoid div by 0
	$curtime = $lasttalked + 1 if($curtime <= $lasttalked);

	# A somewhat continuous fallof. This will assign a score of
	# 18 for 20 minutes, and 3 for two hours, for example.
	# Never let it go below 5.
	my $time_penalty=int(3*60*120 / ($curtime - $lasttalked));
	debug($nick . ":" . $time_penalty . ":" . ($lasttalked - $curtime)) if $debuglev > 2;

	$time_penalty=5 if($time_penalty<5);
	# At this point it's already absurdly high; no need to let it go
	# higher or do more work later. (This corresponds to ~21 seconds.)

	if ($time_penalty>1000) {
		$time_penalty=1000;
		$worth_harder_tests=0 if $recolored==0;
	}
	$color_scores{$session_colors{$channel}{$nick}} = 
		$color_scores{$session_colors{$channel}{$nick}} + $time_penalty;

	# Penalize colors already assigned to recently-used nicks of a similar
	# length.
	#
	# Specifically, run through the last several (currently 40;
	# TODO: make that an option) nicks, and for each one, calculate a
	# penalty for its color based on its similarity to the current name.
	# Two things are taken into account so far: the length, and the first
	# letter.
	# We intentionally include duplicates: if someone's talking a lot, we
	# want to try harder to be a different color.
	if ($worth_harder_tests) {

		# Modest penalty for colours already in use. This will ensure that
		# if there are fewer people than colours, we'll never reuse one.
		my %used_colors;
		foreach my $inick (keys %{$session_colors{$channel}}) {
			$used_colors{$session_colors{$channel}{$inick}} = -2;
		}
		foreach my $color (keys %used_colors) {
			$color_scores{$color} = $color_scores{$color} + $used_colors{$color};
		}

		# Now penalize nicks of people who have spoken recently.
		foreach my $inick (@{$recent_nicks_chan{$channel}}) {
			if ($inick ne $nick) {
				my $penalty = 0;
				my $lendiff = abs(length($nick) - length($inick));
				if ($lendiff == 0) {
					$penalty=-8;
				} elsif ($lendiff == 1) {
					$penalty=-4;
				} else {
					$penalty=-1; # Even if lengths are wildly different, we want to
					             # penalize the color a bit.
				}
				
				# Also penalize nicks that start with the same letter.
				if (substr($nick,0,1) eq substr($inick,0,1)) {
					$penalty = $penalty - 4;
				}
				
				$color_scores{$session_colors{$channel}{$inick}} =
					$color_scores{$session_colors{$channel}{$inick}} + $penalty;
			}
		}
	}

	# For debugging.
	my $cstring='';

	##### Now choose the best color from the list.
	
	my $best_color=-1;
	my $max_val=-100;
	for (my $i=0; $i<11; $i++) {
		$cstring=$cstring . "$i:$color_scores{$i}; ";
		if ($color_scores{$i} > $max_val) {
			$max_val=$color_scores{$i};
			$best_color=$i;
		}
	}
	$cstring = $cstring . "| BEST: $best_color.";
	$color = $best_color;
	
	$session_colors{$channel}{$nick} = $color;

	debug($channel . " <$nick> $msg " . $cstring) if $debuglev > 1;

	$color = $colors[$color % 11];

	$color = "0".$color if ($color < 10);

	return $color;
}

sub sig_public {
	my ($server, $msg, $nick, $address, $target) = @_;

	my $level=Irssi::settings_get_int('colorlevel');

	return if($level<1);

	my $mynick=$server->{nick};

	if($level==2 && $msg=~/^[a-zA-Z0-9_|^\[\]]*[:,] /)
	{
		$msg=~/^([a-zA-Z0-9_|^\[\]]*)([:,] .*)/;
		my $inick=$1;
		my $rest=$2;

		if($mynick ne $inick)
		{
			if(grep {$_->{nick} eq $inick} $server->channel_find($target)->nicks())
			{
				my $color=best_color($server, $msg, $inick, $address, $target);
				
				
				Irssi::signal_emit('message public', 
													 ($server, 
														"".chr(3) .$color.$inick.chr(15).$rest, $nick, $address, $target));
				Irssi::signal_stop();
			}
		}
	}

	my $ch="".chr(3)."|".chr(4);
	if($level==3 && !($msg=~/^($ch)/))
	{
		my $chan=$server->channel_find($target);

		if(!defined($chan))
		{
				return;
		}

		foreach ($chan->nicks())
		{
			my $nick=$_->{nick};
			next if($mynick eq $nick);


			if(index($msg,$nick) != -1)
			{
				my $color=best_color($server, $msg, $nick, $address, $target);
				my $tar=chr(3).$color.$nick.chr(15);
				$msg=~s/(^|\b|\W)(\Q$nick\E)($|\b|\W)/$1.$tar.$3/ge;
			}
		}

		$msg="".chr(4)."g".$msg;

		Irssi::signal_emit('message public', 
											 ($server, 
												$msg, $nick, $address, $target));
		Irssi::signal_stop();
	}

	my $color = best_color($server, $msg, $nick, $address, $target);

	$server->command('/^format pubmsg {pubmsgnick $2 {pubnick '.chr(3).$color.'$0}}$1');
}

sub sig_act_public {
	my ($server, $msg, $nick, $address, $target) = @_;

	my $level=Irssi::settings_get_int('colorlevel');

	return if($level<1);

	my $mynick=$server->{nick};

	my $ch="".chr(3)."|".chr(4);
	if($level==3 && !($msg=~/^($ch)/))
	{
		my $chan=$server->channel_find($target);

		if(!defined($chan))
		{
				return;
		}

		foreach ($chan->nicks())
		{
			my $inick=$_->{nick};

			next if($mynick eq $inick);

			if(index($msg,$inick) != -1)
			{
				my $color=best_color($server, $msg, $inick, $address, $target);
				my $tar=chr(3).$color.$inick.chr(15);
				$msg=~s/(^|\b|\W)(\Q$nick\E)($|\b|\W)/$1.$tar.$3/ge;
			}
		}

		$msg="".chr(4)."g".$msg;

		Irssi::signal_emit('message irc action', 
											 ($server, 
												$msg, $nick, $address, $target));
		Irssi::signal_stop();

		return;
	}

	my $color = best_color($server, $msg, $nick, $address, $target);

  $server->command('/^format action_public  '.chr(2).'*'.chr(2).' '.chr(3).$color.'$0'.chr(15).' {pubnick $1}');
}

sub cmd_color {
	my ($data, $server, $witem) = @_;
	my ($op, $nick, $color) = split " ", $data;

	$op = lc $op;

	if (!$op) {
		Irssi::print ("No operation given");
	} elsif ($op eq "save") {
		save_colors;
	} elsif ($op eq "debug") {
		$debuglev=$nick;
		Irssi::print("Debuglevel set to $debuglev.");
	} elsif ($op eq "set") {
		if (!$nick) {
			Irssi::print ("Nick not given");
		} elsif (!$color) {
			Irssi::print ("Color not given");
		} elsif ($color < 0 || $color > 10) {
			Irssi::print ("Color must be between 0 and 10 inclusive");
		} else {
			$saved_colors{$nick} = $color;
		}
	} elsif ($op eq "clear") {
		if (!$nick) {
			Irssi::print ("Nick not given");
		} else {
			delete ($saved_colors{$nick});
		}
	} elsif ($op eq "list") {
		Irssi::print ("\nSaved Colors:");
		foreach my $nick (keys %saved_colors) {
			Irssi::print (chr (3) . "$colors[$saved_colors{$nick}]$nick" .
										chr (3) . "0 ($saved_colors{$nick})");
		}
	} elsif ($op eq "preview") {
		Irssi::print ("\nAvailable colors:");
		foreach my $i (0..10) {
			Irssi::print (chr (3) . "$colors[$i]" . "Color #$i");
		}
	}
}

sub cmd_recolor {
	my ($nick, $server, $witem) = @_;

	if (!$witem) {
		Irssi::print "Not in a channel!";
		return;
	}

	my %chan=%$witem;
	my $chan_name=$chan{"name"};

	if (!$recolors{$chan_name}) {
		$recolors{$chan_name}={};
		#Irssi::print("Created recolors.");
	}

	$nick =~ s/ //g;

	#Irssi::print("'$nick' $last_talked{$nick}");

	if ($last_talked{$chan_name}{$nick}) {
		Irssi::print("Recoloring $nick in $chan_name...");
		$recolors{$chan_name}{$nick}=1;
	} elsif ($nick eq '-all') {
		Irssi::print("Resetting all colors.");
		$session_colors{$chan_name}={};
	} else {
		Irssi::print("$nick isn't assigned any color!");
	}
}

load_colors;

Irssi::command_bind('color', 'cmd_color');
Irssi::command_bind('recolor', 'cmd_recolor');

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('message irc action', 'sig_act_public');
Irssi::signal_add('event nick', 'sig_nick');

Irssi::settings_add_int('misc','colorlevel',1);
Irssi::settings_add_bool('misc','nickcolor_global',0);
