#!/usr/bin/perl

use strict;
use warnings;
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "1.0-pcd";
%IRSSI = (
    authors         => 'Paul Dagnelie',
    contact         => 'paulcd2000@gmail.com',
    name            => 'trombone',
    description     => 'script to turn make ignored messages more amusing, in a customizeable fashion',
    license         => 'public domain',
    );

my $tromb_hash = {};

sub handle_msg {
    my ($srv, $msg, $nick, $nick_addr, $dstchan) = @_;
    if(exists($tromb_hash->{$nick}) && length($tromb_hash->{$nick})>0){
        my $replace = $tromb_hash->{$nick};
        $msg =~ s/\w+/$replace/g;
        Irssi::signal_continue(($srv,$msg,$nick,$nick_addr,$dstchan));
    }
}

sub cmd_trombone {
    my ($data, $server, $awin) = @_;
    my @l = split(' ',$data);
    if(@l == 2) {
        Irssi::print("Applying the custom trombone to $l[0]: $l[1]");
        $tromb_hash->{$l[0]} = $l[1];
    }
    elsif(@l == 1){
        Irssi::print("Applying the default trombone to $l[0]");
        $tromb_hash->{$l[0]} = 'bwahhh';
    }
    else{
        Irssi::print("Usage: /trombone <name> <optional string>");
    }
}

sub cmd_untrombone{
    my ($data, $server, $awin) = @_;
    my @data2 = split(' ',$data);
    my $data3 = $data2[0];
    if ($data3 && exists($tromb_hash->{$data3}) && length($tromb_hash->{$data3}) > 0){
#        delete $$tromb_hash{$data};
        $tromb_hash->{$data3} = "";
        Irssi::print("Untromboning $data3");
    }
    elsif($data3){
        Irssi::print("No trombone registered for \"$data3\"");
    }
    else{
        Irssi::print("Usage: /untrombone <name>");
    }
}
    

Irssi::signal_add_first("message public", "handle_msg");
Irssi::signal_add_first("message private", "handle_msg");
Irssi::signal_add_first("ctcp action", "handle_msg");

Irssi::command_bind('trombone', 'cmd_trombone');
Irssi::command_bind('untrombone', 'cmd_untrombone');
