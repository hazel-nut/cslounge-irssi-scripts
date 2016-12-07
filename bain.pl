#!/usr/bin/perl

use strict;
use warnings;
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "1.0-pcd";
%IRSSI = (
    authors         => 'hazelnut, h/t pcd',
    contact         => 'github@virdo.name',
    name            => 'bain',
    description     => 'SCRIPT TO BAIN-IFY EVERYTHING SOMEONE SAYS >:[',
    license         => 'public domain',
    );

my $bain_hash = {}; # i'm too lazy to make this a more appropriate data structure

sub handle_msg {
    my ($srv, $msg, $nick, $nick_addr, $dstchan) = @_;
    if(exists($bain_hash->{$nick}) && length($bain_hash->{$nick})>0){
        Irssi::signal_continue(($srv,uc($msg) . ' >:[',$nick,$nick_addr,$dstchan));
    }
}

sub cmd_bain {
    my ($data, $server, $awin) = @_;
    my @l = split(' ',$data);
    if(@l == 1){
        Irssi::print("BAIN-IFYING " . uc($l[0]) . " >:[ ");
        $bain_hash->{$l[0]} = 'bain!';
    }
    else{
        Irssi::print("Usage: /bain <name>");
    }
}

sub cmd_unbain {
    my ($data, $server, $awin) = @_;
    my @data2 = split(' ',$data);
    my $data3 = $data2[0];
    if ($data3 && exists($bain_hash->{$data3}) && length($bain_hash->{$data3}) > 0){
        $bain_hash->{$data3} = "";
        Irssi::print("Un-bain-ifying $data3 :(");
    }
    elsif($data3){
        Irssi::print("\"$data3\" was never bain-ified");
    }
    else{
        Irssi::print("Usage: /unbain <name>");
    }
}
    

Irssi::signal_add_first("message public", "handle_msg");
Irssi::signal_add_first("message private", "handle_msg");
Irssi::signal_add_first("ctcp action", "handle_msg");

Irssi::command_bind('bain', 'cmd_bain');
Irssi::command_bind('unbain', 'cmd_unbain');
