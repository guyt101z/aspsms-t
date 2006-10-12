#!/usr/bin/perl
# aspsms.swissjabber.ch by Marco Balmer <mb@micressor.ch> @2004
# http://web.swissjabber.ch
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

### CONFIGURATION BEGIN ###
my $login		= '';
my $password		= '';
my $originator		= "";
my $target		= $ARGV[0];
my $affiliateid		= '82723';
my $mess		= $ARGV[1];
my $url 		= $ARGV[2];
### CONFIGURATION END ###


use IO::Socket;
use strict;
use ASPSMS::xmlmodel;

my $aspsms_ip    = 'xml1.aspsms.com';
my $aspsms_port  = '5061';
my $aspsmssocket;

unless($ARGV[0] and $ARGV[1] and $login and $password and $originator)
 {
  print "Please configure the script ./aspsms.SendWAPPushSMS.pl
Usage: ./aspsms.SendWAPPushSMS.pl destination \"text\"\n";
  exit(-1);
 }


my $aspsmsrequest 	= xmlSendWAPPushSMS($login,$password,$originator,$target,$mess,$url,'1','1',$target,$affiliateid);
my $aspsmsrequestlength = length($aspsmsrequest);
my $httprequest 	= xmlGenerateRequest($aspsmsrequest,$aspsmsrequestlength);

$aspsmssocket = IO::Socket::INET->new(  PeerAddr => $aspsms_ip,
                                        PeerPort => $aspsms_port,
                                        Proto    => 'tcp',
                                        Timeout  => 5,
                                        Type     => SOCK_STREAM) or die "Connection to aspsms falied!";

print $aspsmssocket $httprequest;
my @answer = <$aspsmssocket>; 

print "Response:\n\n",@answer;

close($aspsmssocket);
