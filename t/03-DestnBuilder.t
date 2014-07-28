#!/usr/bin/perl

use English;
use warnings;
use FindBin;
use IO::File;
use Path::Class;
use Test::Most 'no_plan';
use XML::SAX::ParserFactory;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Destinations;
use DestnPage;

BEGIN {
   use_ok('DestnBuilder');
}

{
    my $builder = testNewBuilder();
    testHandle($builder);
}

sub testNewBuilder {
   die_on_fail;
   my $pg = DestnPage->new(destinations => Destinations->new(file => Path::Class::File->new($FindBin::Bin,'Data','destinations.xml')),
      path => Path::Class::Dir->new($FindBin::Bin,'..','destinations')->resolve,
      templateConfig => Path::Class::File->new($FindBin::Bin,'..','cfg','Template.cfg')->resolve
   );
   my $builder = new_ok('DestnBuilder' => [destnPage => $pg], 'Test new Taxonomy Handler object');
   
   can_ok($builder, qw/destnPage/);
   restore_fail;
   return($builder);
}

sub testHandle {
   my ($builder) = @_;
   
   my $parsr = XML::SAX::ParserFactory->parser(Handler => $builder);
   $parsr->parse_uri(Path::Class::File->new($FindBin::Bin,'Data','taxo_test.xml')->resolve->stringify);
}