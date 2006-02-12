# aspsms-t by Marco Balmer <mb@micressor.ch> @2005
# http://web.swissjabber.ch/
# http://www.micressor.ch/content/projects/aspsms-t/
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

package ASPSMS::aspsmstlog;

use strict;
use vars qw(@EXPORT @ISA);
use Exporter;

@ISA 			= qw(Exporter);
@EXPORT 		= qw(aspsmst_log);


use Sys::Syslog;


sub aspsmst_log
 {
   my $type      = shift;
   my $msg       = shift;

   unless ($type eq 'debug')
    {
     print "\n$type>   $msg";
    }
   else
    {
     print "\n\nDEBUG:\n-----\n$msg\n-----";
    }



   # Debug informations only to STDOUT
   unless ($type eq 'debug')
    {
     syslog($type,$msg);
    }

 }

1;

