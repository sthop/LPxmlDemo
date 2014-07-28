#!/usr/bin/perl

use English;
use warnings;
use Date::Manip;
use FindBin;
use Getopt::Long;
use Path::Class;
use Log::Log4perl;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Destinations;

Date_Init("DateFormat=Non-US","setdate=now,Australia/Melbourne");

{
   Log::Log4perl::init(Path::Class::File->new($FindBin::Bin,'..','cfg','destnBuilder.log.cfg')->resolve->stringify);
   GetOptions ('taxonomy|t=s' => \(my $taxonomy),
      'destinations|d=s' => \(my $destn));
   my $destnFile = Destinations->new(file => $destn);
   
   print '';
   
}

sub loggerFileName {
   my $date = ParseDate('now');
   return(Path::Class::File->new($FindBin::Bin,'..','log','destnBuilder-'.UnixDate($date,'%Q-%H%M%S').'.log'));
}