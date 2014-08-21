################################################################################
# Author: Sten Hopkins
################################################################################

package Test::Destinations;

use English;
use warnings;
use FindBin;
use JSON;
use Path::Class;
use Test::Class::Moose;
use Test::Moose::More;
use utf8;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Args;

with 'Test::Class::Moose::Role::AutoUse';
with 'Role::Argv';

################################################################################
# Attributes:
################################################################################

has 'test_destinations' => (isa => 'Destinations',
   is => 'rw',
   documentation => q/Destinations object used for the tests/
);

has 'dataDir' => (isa => 'Path::Class::Dir',
   is => 'rw',
   default => sub {Path::Class::Dir->new($FindBin::Bin,'Data')},
   documentation => q/Data dir for files used in the tests/
);

has '_testCases' => (isa => 'HashRef',
   is => 'rw',
   builder => '_setTestCases',
   documentation => q/Hash of arrays containing sets of test case data./
);

################################################################################
# Test Method
# Automatically called at start of Test Destinations class
################################################################################
sub test_startup {
   my $test = shift;
   
   $test->next::method;
   $test->test_destinations(
      $test->class_name->new(file => Path::Class::File->new($test->dataDir,'destntest.xml'))
   );
}

################################################################################
# Public Method
# Authomatically called before each test method
################################################################################
sub test_setup {
   my $test = shift;
   
   $test->next::method;
   if ($test->test_report->current_method->name =~ /instantiation_with_defaulting_file/) {
      $test->alterArgv('-t' => 'dummy_taxonomy', '-p' => 'dummy_path',
      '-d' => Path::Class::File->new($test->dataDir,'destntest.xml')->stringify);
      Args->initialize;
   }
}

################################################################################
# Public Method
################################################################################
sub test_01_constructor {
   my $test = shift;

   my $destn = $test->test_destinations;
   
   does_ok($destn,'Role::PathClassable', 'does Role PathClassable which allows coercing of string into Path::Class::File/Dir type');
   does_ok($destn,'Role::Notifiable', 'does Role Notifiable');
   
   has_attribute_ok($destn,'file', 'Has a "file" attribute');
   has_attribute_ok($destn,'encoding', 'Has an "encoding" attribute');
   
   has_method_ok($destn,'getDestination','destinationTitles');
}

################################################################################
# Public Method
################################################################################
sub test_instantiation_with_defaulting_file_from_args {
   my $test = shift;
   
   my $destinations;
   lives_ok { $destinations = $test->class_name->new() } 'Instantiate defaulting file from args';
   is ($destinations->file->stringify,
      Path::Class::File->new($test->dataDir,'destntest.xml')->stringify,
      'file contains value from command line args');
}

################################################################################
# Public Method
################################################################################
sub test_instantiation_failures_throw_exception {
   my $test = shift;

   throws_ok { Destinations->new(file => Path::Class::File->new($test->dataDir,'not_there.xml')) } qr/Failed to open the Destinations file/,
      'Unable to open missing file throws exception';

   foreach my $invalidCase (@{$test->_testCases->{instantiateTests}}) {
      SKIP: {
         my $file = Path::Class::File->new($test->dataDir,$invalidCase->{file});
         skip $file->basename.' test file is missing'
            if (!ok(-e $file, $file->basename.' exists'));
         throws_ok { Destinations->new(file => $file) } qr/$invalidCase->{regex}/, $invalidCase->{description};
      }
   }
}

################################################################################
# Public Method
################################################################################
sub test_02_getting_destinations {
   my $test = shift;
   my $dest = $test->test_destinations;
   
   ok(!defined($dest->getDestination('111111')),"Can't get destination record for unindexed atlas_id");
   ok(!defined($dest->destinationTitles('111111')),"Can't get title details for unindexed atlas_id");
   throws_ok { $dest->getDestination('355613') } qr/Invalid XML Record parsed/, 'Malformed XML Record throws exception';
   
   #loop through each test case (from the DATA section below) for testing "getDestination"
   foreach my $destnCase (@{$test->_testCases->{getDestnRecTests}}) {
      my $doc;
      SKIP: {
         #testing "getDestination" will retrieve the correct record, expecting a XML DOM object to be returned
         subtest 'retrieving destination document for '.$destnCase->{atlas_id}.' is valid and correct' => sub {
            plan 'no_plan';
            skip 'Exception raised, getting destination record for '.$destnCase->{atlas_id}
               if (!lives_ok { $doc = $dest->getDestination($destnCase->{atlas_id}) } 'xml record for '.$destnCase->{atlas_id}.' correctly parsed without error');
            skip 'Expecting an XML::DOM::Document'
               if (!isa_ok($doc,'XML::DOM::Document',$doc));
            skip 'Expecting to get back the document level element'
               if (!ok(my $docElem = $doc->getDocumentElement,'document level Element'));
            skip 'Expecting element to be a "destination element"'
               if (!is($docElem->getTagName,'destination', 'document level Element is "destination"'));
            skip 'Expecting the "destination" element to have "atlas_id" attribute'
               if (!ok($docElem->getAttributeNode('atlas_id'),'destination attribute "atlas_id" exists'));
            is($docElem->getAttribute('atlas_id'),$destnCase->{atlas_id}, 'atlas_id has the correct id');
         };
         my $titles = $dest->destinationTitles($destnCase->{atlas_id});
         ok(utf8::is_utf8($titles->{title}),'Title is utf8');
         cmp_deeply($titles,{title => $destnCase->{title}, title_ascii => $destnCase->{title_ascii}},'Destination Title attributes');
      }
      $doc->dispose if ($doc); #clean up DOM object
   } #foreach
}

################################################################################
# Public Method
# Automatically called after every Test method.
################################################################################
sub test_teardown {
   my $test = shift;

   $test->next::method;
   if ($test->test_report->current_method->name =~ /instantiation_with_defaulting_file/) {
      $test->restoreArgv();
      Args->clear;
   }
}

################################################################################
# Private Method _setTestCases
# Reads the JSON text in the __DATA__ section below and sets the _testCases
# attribute.
################################################################################
sub _setTestCases {
   my $self;

   my $json = JSON->new();
   my @data = <DATA>;
   close(DATA);
   my $jsonStr = join('',@data);
   my $data = $json->decode($jsonStr);
   $data;
}


__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################

1;

__DATA__
{
   "instantiateTests" : [
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
         "description" : "No destination records found throws exception"
      },
      {
         "file" : "dest_duplicate_atlas_id.xml",
         "regex" : "atlas id \\[\\d+\\] is not unique in",
         "description" : "duplicate atlas id detected throws exception"
      }
   ],
   "getDestnRecTests" : [
      {
         "atlas_id" : "355611",
         "title" : "South Africa",
         "title_ascii" : "South Africa"
      },
      {
         "atlas_id" : "355064",
         "title" : "Africaö조",
         "title_ascii" : "Africa"
      },
      {
         "atlas_id" : "355614",
         "title" : "Free State",
         "title_ascii" : "Free State"
      },
      {
         "atlas_id" : "355612",
         "title" : "Cape Town",
         "title_ascii" : "Cape Town"
      }
   ]
}
