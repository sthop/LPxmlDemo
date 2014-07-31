#!/usr/bin/perl

use English;
use warnings;
use FindBin;
use JSON;
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
   
   my $dest;
   my $dataDir = Path::Class::Dir->new($FindBin::Bin,'Data');
   
   #Test exception thrown with non-existent destination file
   throws_ok { $dest = Destinations->new(file => Path::Class::File->new($dataDir,'not_there.xml')) } qr/Failed to open the Destinations file/,
      'Unable to open missing file throws exception';

   my $InvalidDestXMLs = decodeData();
   foreach my $invalid (@{$InvalidDestXMLs}) {
      SKIP: {
         my $file = Path::Class::File->new($dataDir,$invalid->{file});
         skip $file->basename.' test file is missing'
            if (!ok(-e $file, $file->basename.' exists'));
         throws_ok {$dest = Destinations->new(file => $file)} qr/$invalid->{regex}/, $invalid->{description};
      }
   }
   
   $dest = new_ok('Destinations' => [file => Path::Class::File->new($dataDir,'destntest.xml')], 'Test new Destinations object');
   
   can_ok($dest, qw/file encoding getDestination destinationTitles/);
   restore_fail;
   return($dest);
}

#Test method of the Destination class
sub testGetDestRec {
   my ($dest) = @_;

    throws_ok { $dest->getDestination('355613') } qr/Invalid XML Record parsed/, 'Malformed XML Record throws exception';
   
   my $doc = $dest->getDestination('355064');
   isa_ok($doc,'XML::DOM::Document',$doc);
   is($doc->getNodeName,'#document','node is a document');
   my $docElem;
   ok($docElem = $doc->getDocumentElement,'document level Element');
   is($docElem->getTagName,'destination', 'document level Element is "destination"');
   ok($docElem->getAttributeNode('atlas_id'),'destination attribute "atlas_id" exists');
   is($docElem->getAttribute('atlas_id'),'355064', 'atlas_id has the correct id');
   
   my $titles = $dest->destinationTitles('355064');
   cmp_deeply($titles,{title => 'Africaö', title_ascii => 'Africa'},'Destination Title attributes');
}

sub decodeData {
   my $json = JSON->new();
   my @data = <DATA>;
   close(DATA);
   my $jsonStr = join('',@data);
   my $data = $json->decode($jsonStr);
   $data;
}

__DATA__;
[
   {
      "file" : "dest_no_xml_decl.xml",
      "regex" : "Missing XML declaration in",
      "description" : "Missing xml decl in destination xml throws exception"
   },
   {
      "file" : "dest_missing_atlas_id.xml",
      "regex" : "element appears to be missing attribute \"atlas_id\"",
      "description" : "Missing attribute atlas_id throws exception"
   },
   {
      "file" : "dest_missing_title.xml",
      "regex" : "Element node for destination record.+missing attribute \"title\"",
      "description" : "Missing attribute title throws exception"
   },
   {
      "file" : "dest_missing_title_ascii.xml",
      "regex" : "Element node for destination record.+missing attribute \"title-ascii\"",
      "description" : "Missing attribute title-ascii throws exception"
   },
   {
      "file" : "dest_unmatched_start_elem.xml",
      "regex" : "Unmatched destination start element tag in",
      "description" : "Unmatched destination start element throws exception"
   },
   {
      "file" : "dest_unmatched_end_elem.xml",
      "regex" : "Unmatched destination closing element tag in",
      "description" : "Unmatched destination closing element throws exception"
   },
   {
      "file" : "dest_no_records.xml",
      "regex" : "No destination records found in",
      "description" : "Nod destination records found throws exception"
   }
]