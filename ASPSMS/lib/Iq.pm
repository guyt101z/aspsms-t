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

package Iq;

use strict;
use ASPSMS::config;
use vars qw(@EXPORT @ISA);
use Exporter;

@ISA 			= qw(Exporter);
@EXPORT 		= qw(	InIQ 
				SendIQError 
				jabber_register 
				jabber_iq_gateway
				jabber_iq_register 
				jabber_iq_browse 
				jabber_iq_disco_info 
				jabber_iq_disco_items 
				jabber_iq_xmlsrv
			   );


use Sys::Syslog;
use ASPSMS::aspsmstlog;
use ASPSMS::Jid;
use ASPSMS::xmlmodel;
use ASPSMS::Connection;
use ASPSMS::userhandler;
use ASPSMS::Message;
use ASPSMS::Storage;
use ASPSMS::DiscoNetworks;
use ASPSMS::Presence;


my $admin_jid	= $ASPSMS::config::admin_jid;
my $passwords	= $ASPSMS::config::passwords;

sub InIQ {

 # Incoming IQ. Handle jabber:iq:registration with add/remove source 
 # dialog, return error 501 for other NS's.

 $ASPSMS::config::aspsmst_stat_stanzas++;

 my $sid 	= shift;
 my $iq 	= shift;
 my $from 	= $iq->GetFrom();
 my $to 	= $iq->GetTo();
 my $id 	= $iq->GetID();
 my $type 	= $iq->GetType();
 my $query 	= $iq->GetQuery();
 my $xml	= $iq->GetXML();
 my $barejid	= get_barejid($from);

aspsmst_log('debug',"InIQ->GetXML(): $xml");

if ($to eq "$ASPSMS::config::service_name/xmlsrv.asp") 
 {
  my $ret = jabber_iq_xmlsrv($sid,$iq,$from,$to,$id,$type,$query,$xml);
 } ### END jabber:iq:xmlsrv.asp ###

return unless $query;
my $xmlns 	= $query->GetXMLNS();

aspsmst_log('debug',"id=$id InIQ($barejid): Processing iq query type=$type xmlns=\"$xmlns\"");

# If error in <iq/> 
if ($type eq 'error') 
{
 aspsmst_log('debug',"InIQ->GetXML(): " . $iq->GetXML());
 return;
}

if ($xmlns eq 'jabber:iq:register') 
 {
  my $ret = jabber_register($sid,$iq,$from,$to,$id,$type,$query,$xml);
 } ### END jabber:iq:register ###
elsif ($xmlns eq 'jabber:iq:gateway') 
 {
  my $ret = jabber_iq_gateway($sid,$iq,$from,$to,$id,$type,$query,$xml);
 } ### END jabber:iq:gateway ###
elsif ($xmlns eq 'jabber:iq:browse') 
 {
  my $ret = jabber_iq_browse($sid,$iq,$from,$to,$id,$type,$query,$xml);
 } ### END jabber:iq:browse ###
elsif ($xmlns eq 'http://jabber.org/protocol/disco#info')
 {
   my $ret = jabber_iq_disco_info($sid,$iq,$from,$to,$id,$type,$query,$xml);
 }
elsif ($xmlns eq 'http://jabber.org/protocol/disco#items')
 {
  my $ret = jabber_iq_disco_items($sid,$iq,$from,$to,$id,$type,$query,$xml);
 }
elsif ($xmlns eq 'jabber:iq:version') 
  {
   if ($type eq 'get') 
    {
     $iq->SetType('result');
     $iq->SetFrom($iq->GetTo());
     $iq->SetTo($from);
     $query->SetName($ASPSMS::config::browseservicename);
     $query->SetVer($ASPSMS::config::release);
     $query->SetOS($^O);
     $ASPSMS::config::Connection->Send($iq);
    }
   else 
    {
     sendError($iq, $from, $to, 501, 
     		"Sorry, $ASPSMS::config::ident does not support $xmlns");
    }
   }
  else 
   {
    sendError($iq, $from, $to, 501, 
    		"Sorry, $ASPSMS::config::ident does not support $xmlns");
   }

} ### END of InPresence ###

sub SendIQError {
my $id		= shift;
my $to	  	= shift;
my $errorcode 	= shift;
my $error 	= shift;
my $iq;

  aspsmst_log('info',"SendIQError(): Sending IQ to $to");
  $iq = new Net::Jabber::IQ();

  $iq->SetIQ(		type		=>"error",
                       	to		=>$to,
                       	errorcode	=>$errorcode,
                       	error		=>$error,
			from		=>$ASPSMS::config::service_name,
                      	id		=>$id);			


$ASPSMS::config::Connection->Send($iq);
}

sub jabber_register

{
my $sid 	= shift;
my $iq 		= shift;
my $from 	= $iq->GetFrom();
my $to 		= $iq->GetTo();
my $id 		= $iq->GetID();
my $type 	= $iq->GetType();
my $query 	= $iq->GetQuery();
my $xml		= $iq->GetXML();
my $banner	= $ASPSMS::config::banner;

  if ($type eq 'get') 
   {
    $iq->SetType('result');
    $iq->SetFrom($iq->GetTo());
    $iq->SetTo($from);
    aspsmst_log('info',"jabber_register(): Send instructions to $from");
    $query->SetInstructions("$ASPSMS::config::ident $ASPSMS::config::release transport

Please enter Username 
(https://www.aspsms.ch/userkey.asp) and 
password of your aspsms.com account.
Support contact xmpp: $ASPSMS::config::admin_jid");

    my $ret_user 	= getUserPass($from,$banner);
    my $user 		=  {};

    if($ret_user == -2)
     {
      #
      # If no user found, reset $user var
      #
      $user->{name}           = '' if ( ! $user->{name} );
      $user->{password}       = '' if ( ! $user->{password} );
      $user->{phone}          = 'aspsms-t' if ( ! $user->{phone} );
      $user->{signature}      = $banner if (! $user->{signature} );
     }
    else
     {
      $user = $ret_user;
     }
    
    $query->SetUsername($user->{name});
    $query->SetURL($user->{signature});
    $query->SetPhone($user->{phone});
    $query->SetPassword('');
    $ASPSMS::config::Connection->Send($iq);
   }
  elsif ($type eq 'set') 
   {
    my $gateway 	= 'aspsms'; # TODO! ->GetName() but only one gateway with passwords so far
    my $name 		= $query->GetUsername();
    my $phone 		= $query->GetPhone();
    my $pass 		= $query->GetPassword();
    my $signature 	= $query->GetURL();
    my $remove		= $query->GetRemove();

  my ($barefrom)  	= get_barejid($from);
  my $passfile 		= "$ASPSMS::config::passwords/$barefrom";
  $phone          	=~ s/\+/00/g;

  #
  # Remove = 1 ?????
  #
  aspsmst_log('notice',"jabber_register(): remove flag: $remove for $from");
  unless ($remove == 1) 
   {
    jabber_iq_remove($from,$id,$passfile);
    return;
   } # if ($remove) {

    # check aspsms user trough gateway of aspsms.com
    my ($ErrorCode,$ErrorDescription) = CheckNewUser($name,$pass);
    unless($ErrorCode == 1)
     {
      #
      # Convert aspsms.com error codes in jabber compilant (XEP-0086) codes
      #
      $ErrorCode =~ s/26/406/g;
      $ErrorCode =~ s/3/401/g;
      SendIQError($id,$from,$ErrorCode,$ErrorDescription);
      return;
     };
			
  #
  # Check: Is already another jid with the same USERKEY 
  # 	   registered? If yes, reject registration of
  # 	   this jid.
  #
  #

  my $check_two_userdata 	= get_record("userkey",$name);

  unless($check_two_userdata == -2)
   {
    my $check_two_jid	= $check_two_userdata->{jid};
    unless($barefrom eq $check_two_jid)
     {
      SendIQError($id,$from,406,"You have already another jid registered with the same userkey. Please unregister first your registration from $check_two_jid");
      return 1;
     } ### unless($barefrom eq $check_two_jid)
   } ### unless($check_two_userdate == -2)

  #
  # store configuration to the spool directory
  # via set_record();
  #

  my $userdata = {};
  $userdata->{gateway} 	= $gateway; 
  $userdata->{name} 	= $name; 
  $userdata->{pass} 	= $pass; 
  $userdata->{phone} 	= $phone; 
  $userdata->{signature}= $signature; 

  my $ret_record = set_record("jabber_register",$passfile,$userdata);

  aspsmst_log('info',"jabber_register(): RegisterManager.Execute: set_record(): Return: $ret_record for $from");

  $iq->SetType('result');
  $iq->SetFrom($iq->GetTo());
  $iq->SetTo($from);
  $ASPSMS::config::Connection->Send($iq);
  sendAdminMessage("info","RegisterManager.Complete: set_record(): Return: $ret_record for $from $name:$phone:$pass:$signature");

  my $presence = new Net::Jabber::Presence();
  
  aspsmst_log('info',"jabber_register(): RegisterManager.Complete: for $from $name:$phone:$pass:$signature");
  
  sendPresence($from,"$ASPSMS::config::service_name/registered", 'subscribe');
 } else 
    {
     sendError($iq, $from, $to, 501, 'feature-not-implemented: jabber:iq:register');
    }
} # END of jabber_register

### jabber_iq_gateway ####
sub jabber_iq_gateway 
{
my $sid 	= shift;
my $iq 		= shift;
my $from 	= $iq->GetFrom();
my $to 		= $iq->GetTo();
my $id 		= $iq->GetID();
my $type 	= $iq->GetType();
my $query 	= $iq->GetQuery();
my $xml		= $iq->GetXML();

     if ($type eq 'get') 
     {
      $iq->SetType('result');
      $iq->SetFrom($iq->GetTo());
      $iq->SetTo($from);
      $query->SetDesc('Choose your destination number like: +4179xxxxxxx');
      $query->SetPrompt('Number');
      $ASPSMS::config::Connection->Send($iq);

      aspsmst_log('info',"jabber_iq_gateway($from): Send gateway information");
     } 
    elsif ($type eq 'set') 
     {
      my $number = $query->GetPrompt();
      if ( $number =~ /\+[0-9]{3,50}/ ) 
       { }
      else
       {
        sendError($iq, $from, $to, 406, 'Number format not acceptable');		
       }

   $iq->SetType('result');
   $iq->SetFrom($iq->GetTo());
   $iq->SetTo($from);
   $query->SetPrompt("$number\@$ASPSMS::config::service_name");
   $query->SetJID("$number\@$ASPSMS::config::service_name");
   $ASPSMS::config::Connection->Send($iq);
  }
 else 
  {
   sendError($iq, $from, $to, 501, 'feature-not-implemented');
  }
} ### END of jabber_iq_gateway

### jabber_iq_browse ###
sub jabber_iq_browse
{
my $sid 	= shift;
my $iq 		= shift;
my $from 	= $iq->GetFrom();
my $to 		= $iq->GetTo();
my $id 		= $iq->GetID();
my $type 	= $iq->GetType();
my $query 	= $iq->GetQuery();
my $xml		= $iq->GetXML();  
my $barejid	= get_barejid($from);

  my $namespaces = [ 'jabber:iq:register', 'jabber:iq:gateway','jabber:iq:version' ];

  if ($type eq 'get') 
   {
    aspsmst_log('debug',"id=$id jabber_iq_browse($barejid): Processing iq browse query type=$type");
    $iq->SetType('result');
    $iq->SetFrom($iq->GetTo());
    $iq->SetTo($from);
    $query->SetJID($ASPSMS::config::service_name);
    $query->SetCategory("service");
    $query->SetType($ASPSMS::config::browseservicetype);
    $query->SetName($ASPSMS::config::browseservicename);
    $query->SetNS($namespaces);
    $ASPSMS::config::Connection->Send($iq);
    
   }
  else 
   {
    sendError($iq, $from, $to, 501, 'feature-not-implemented');
   }

} ### END of jabber:iq:browse

sub jabber_iq_disco_info
{
my $sid 	= shift;
my $iq 		= shift;
my $from 	= $iq->GetFrom();
my $to 		= $iq->GetTo();
my $id 		= $iq->GetID();
my $type 	= $iq->GetType();
my $query 	= $iq->GetQuery();
my $xml		= $iq->GetXML();
my $barejid	= get_barejid($from);

if($to eq $ASPSMS::config::service_name)
 {
   if ($type eq 'get')
    {
    aspsmst_log('debug',"id=$id jabber_iq_disco_info($barejid): Processing query type=$type");
    $iq->SetType('result');
    $iq->SetFrom($iq->GetTo());
    $iq->SetTo($from);
    
    my $iqQuery = $iq->NewQuery("http://jabber.org/protocol/disco#info");


    $iqQuery->AddIdentity(	category=>"gateway",
                        	type=>"sms",
				name=>$ASPSMS::config::browseservicename);

    $iqQuery->AddFeature(var=>"http://jabber.org/protocol/disco");
    $iqQuery->AddFeature(var=>"http://www.aspsms.com/xml/doc/xmlsvr18.pdf");
    $iqQuery->AddFeature(var=>"jabber:iq:register");
    $iqQuery->AddFeature(var=>"jabber:iq:gateway");
    $iqQuery->AddFeature(var=>"jabber:iq:version");

    $ASPSMS::config::Connection->Send($iq);


    } # END of if ($type eq 'get'
} ### END of if($to eq $ASPSMS::config::service_name)

} ### END of jabber_iq_disco_info ###

### jabber_iq_disco_items ###
sub jabber_iq_disco_items
{
my $sid 	= shift;
my $iq 		= shift;
my $from 	= $iq->GetFrom();
my $to 		= $iq->GetTo();
my $id 		= $iq->GetID();
my $type 	= $iq->GetType();
my $query 	= $iq->GetQuery();
my $xml		= $iq->GetXML();
my $barejid	= get_barejid($from);

    my $iqQuery = $iq->NewQuery("http://jabber.org/protocol/disco#items");

    if($type eq 'get')
     {
        aspsmst_log('debug',"id=$id jabber_iq_disco_items($barejid): Processing query type=$type");

    #
    # Offer supported networks
    #

    if($to eq $ASPSMS::config::service_name)
     {
      aspsmst_log('debug',"jabber_iq_disco_items($barejid): Display transport items");
      $iqQuery->AddItem(jid=>"countries\@$ASPSMS::config::service_name",
    			name=>"Supported sms networks");
     } ### END of if($to eq $ASPSMS::config::service_name)


    #
    # Display all availavle countries and network operators for sending
    # sms messages
    #

    $iqQuery = disco_get_aspsms_networks($iqQuery,$barejid,$to);

      	$iq->SetType('result');
      	$iq->SetFrom($iq->GetTo());
      	$iq->SetTo($from);
      	$iq->SetID($id);
      	$ASPSMS::config::Connection->Send($iq);
        aspsmst_log('debug',"jabber_iq_disco_items($barejid): Processing finished");
    }
} ### END of jabber_iq_disco_items ###

sub jabber_iq_xmlsrv
{
my $sid 	= shift;
my $iq 		= shift;
my $from 	= $iq->GetFrom();
my $to 		= $iq->GetTo();
my $id 		= $iq->GetID();
my $type 	= $iq->GetType();
my $xml		= $iq->GetXML();
my $barejid	= get_barejid($from);
aspsmst_log('info',"id=$id jabber_iq_xmlsrv($barejid): Processing xmlsrv.asp query");

	#
	# Direct access to the aspsms:com xml srv
	#

	if ($type eq 'set')
	 {
	   aspsmst_log('debug',"XMPP:\n $xml");
	   
	   # processing request to aspsms and wait for result
	   my $xmlsrv_completerequest  = xmlGenerateRequest($xml);
	   my $xmlsrv_completerequest_1 = $xmlsrv_completerequest . "\r\n\r\r\n";
	   my @ret_CompleteRequest 	  	= exec_ConnectionASPSMS($xmlsrv_completerequest_1);

    	   my $iq_xmlsrv_result = new Net::Jabber::IQ();
	   
    	   $iq_xmlsrv_result->SetType('result');
           $iq_xmlsrv_result->SetFrom($iq->GetTo());
           $iq_xmlsrv_result->SetID($id);
           $iq_xmlsrv_result->SetTo($from);
	   my $ret_parsed_response = parse_aspsms_response(\@ret_CompleteRequest,undef);
	   $iq_xmlsrv_result->InsertRawXML($ret_parsed_response);
           $ASPSMS::config::Connection->Send($iq_xmlsrv_result);
	   return undef;
	 } ### END of if ( $to eq $ASPSMS::config::service_name."/xmlsrv.asp")

	#
	# END of Direct access to the aspsms:com xml srv
	#
} ### END of jabber_iq_xmlsrv ###

sub jabber_iq_remove
{
 my $from	= shift;
 my $id		= shift;
 my $passfile	= shift;
 my $barejid	= get_barejid($from);

    aspsmst_log('info',"jabber_register($barejid): Execute remove registration of $passfile");

    #
    # remove file	
    #

    my $ret_unlink = delete_record("jabber_register",$passfile);
    aspsmst_log('info',"jabber_register($barejid): Execute remove completed delete_record($passfile): Return $ret_unlink");

    #
    # If delete of passfile was successfully then send presence 
    # unsubscribe
    #

    if($ret_unlink == 0)
    {
    
    #
    # send unsubscribe presence
    # 
    
    my $presence = new Net::Jabber::Presence;	
    sendPresence($presence, $from,"$ASPSMS::config::service_name/registered", 'unsubscribe');
    
    #
    # send iq result
    # 
    my $barefrom	= get_barejid($from);
    my $iq	= new Net::Jabber::IQ;
    $iq->SetIQ(	type	=>"result",
              	to	=>$barefrom,
		from	=>$ASPSMS::config::service_name,
               	id	=>$id);			

    $ASPSMS::config::Connection->Send($iq);

    my $message = new Net::Jabber::Message();
    $message->SetMessage(
			type	=>"",
			to	=>$barefrom,
			from	=>$ASPSMS::config::service_name,
			body	=>"Sucessfully unregistred" );

    $ASPSMS::config::Connection->Send($message);
    }

return $ret_unlink;
}


1;