#!/usr/bin/env perl

use English;
use warnings;
use Date::Manip;
use FindBin;
use Path::Class;
use Log::Log4perl;
use XML::SAX::ParserFactory;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Args;
use DestnBuilder;
use DestnPage;

Date_Init("DateFormat=Non-US","setdate=now,Australia/Melbourne");

{
   my $cfgPath = Path::Class::Dir->new($FindBin::Bin,'..','cfg')->resolve;
   Log::Log4perl::init(Path::Class::File->new($cfgPath,'destnBuilder.log.cfg')->stringify);
   my $args = Args->initialize();
   my $dPage = DestnPage->new(templateConfig => Path::Class::File->new($cfgPath,'Template.cfg'));
   my $builder = DestnBuilder->new(destnPage => $dPage);
   my $parser = XML::SAX::ParserFactory->parser(Handler => $builder);
   
   $parser->parse_uri($args->taxonomy);
}

#Dynamically set the Log4perl log file name.
sub loggerFileName {
   my $date = ParseDate('now');
   return(Path::Class::File->new($FindBin::Bin,'..','log','destnBuilder-'.UnixDate($date,'%Q-%H%M%S').'.log'));
}
