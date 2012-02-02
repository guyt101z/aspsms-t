# aspsms-t
# http://www.swissjabber.ch/
# https://github.com/micressor/aspsms-t
#
# Copyright (C) 2006-2012 Marco Balmer <marco@balmer.name>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Library General Public License as published
# by the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
# USA.

package ASPSMS::Regex;

use strict;
use vars qw(@EXPORT @ISA);
use ASPSMS::aspsmstlog;

use Exporter;
use Sys::Syslog;

openlog($ASPSMS::config::ident,'','user');


@ISA 				= qw(Exporter);
@EXPORT 			= qw(regexes);



########################################################################
sub regexes {
########################################################################
my $mess        = shift;
my $number      = shift;
my $signature   = shift;

        # Translations / Substitutionen
        $number         = "00" . $number;
        $mess =~ s/\xC3(.)/chr(ord($1)+64)/egs;

	# stupid aspsms xmlsrv failure fixes. These are characters,
	# the aspsms xml server has problems. 
	$mess =~ s/\&//g;
	$mess =~ s/\|//g;
	$mess =~ s/\>//g;
	$mess =~ s/\<//g;
	$mess =~ s/\'//g;
        
	my $mess_length = length($mess);
        my $signature_length    = length($signature);

        my $sms_length =  $mess_length + $signature_length;

        if ($sms_length <=160)
                                {
                                aspsmst_log('debug',"regexes(): Signature: enabled");
                                $mess = $mess . " " . $signature;
                                }
return ($mess,$number);
########################################################################
}
########################################################################

1;
