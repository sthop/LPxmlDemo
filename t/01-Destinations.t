#!/usr/bin/perl

use English;
use warnings;
use FindBin;
use Path::Class;
use Test::Most 'no_plan';
use utf8;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);

BEGIN {
   use_ok('Destinations');
}

{
    my $dest = testNewDestinations();
    testGetDestRec($dest);
}

#Test creating a new Destinations object
sub testNewDestinations {
   die_on_fail;
   my $dest = new_ok('Destinations' => [file => Path::Class::File->new($FindBin::Bin,'Data','destinations.xml')], 'Test new Destinations object');
   
   can_ok($dest, qw/file encoding getDestination destinationTitles/);
   restore_fail;
   return($dest);
}

#Test method of the Destination class
sub testGetDestRec {
   my ($dest) = @_;
   
   my $doc = $dest->getDestination('355064');
   isa_ok($doc,'XML::DOM::Document',$doc);
   is($doc->getNodeName,'#document','node is a document');
   my $docElem;
   ok($docElem = $doc->getDocumentElement,'document level Element');
   is($docElem->getTagName,'destination', 'document level Element is "destination"');
   ok($docElem->getAttributeNode('atlas_id'),'destination attribute "atlas_id" exists');
   is($docElem->getAttribute('atlas_id'),'355064', 'atlas_id has the correct id');
   
   my $titles = $dest->destinationTitles('355064');
   cmp_deeply($titles,{title => 'Africaö', title_ascii => 'Africa'},'Destination Titles');
   print '';
}