################################################################################
# Author: Sten Hopkins
################################################################################

package Test::DestnBuilder;

use English;
use warnings;
use FindBin;
use JSON;
use Path::Class;
use Test::Class::Moose;
use Test::Moose::More;
use MooseX::Privacy;
use XML::SAX::ParserFactory;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Destinations;
use DestnContent;
use DestnPage;

with 'Test::Class::Moose::Role::AutoUse';
with 'Role::Argv';

################################################################################
# Attributes:
################################################################################

has 'test_destnBuilder' => (isa => 'DestnBuilder',
   is => 'rw',
   documentation => q/Destinations object used for the tests/
);

has 'dataDir' => (isa => 'Path::Class::Dir',
   is => 'rw',
   default => sub {Path::Class::Dir->new($FindBin::Bin,'Data')},
   documentation => q/Data dir for files used in the tests/
);

has '_testPath' => (isa => 'Path::Class::Dir',
   is => 'rw',
   lazy => 1,
   traits => ['Protected'],
   builder => '_set_testPath',
   documentation => q/Holds a test path for testing the generation of html pages./
);

################################################################################
# Test Method
# Automatically called at start of Test Destinations class
################################################################################
sub test_startup {
   my $test = shift;
   
   $test->next::method;
   my $destContent = DestnContent->new(destinations => 
      Destinations->new(file => Path::Class::File->new($test->dataDir,'destntest.xml'))
   );
   my $destPg = DestnPage->new(path => $test->_testPath,
      templateConfig => Path::Class::File->new($FindBin::Bin,'..','cfg','Template.cfg')->resolve
   );
   $test->test_destnBuilder(
      $test->class_name->new(destnContent => $destContent, destnPage => $destPg)
   );
}

################################################################################
# Public Method
# Authomatically called before each test method
################################################################################
sub test_setup {
   my $test = shift;
   
   $test->next::method;
   if ($test->test_report->current_method->name =~ /construct_with_default_destn_content/) {
      $test->alterArgv('-t' => 'dummy_taxonomy', '-p' => $test->_testPath->stringify,
      '-d' => Path::Class::File->new($test->dataDir,'destntest.xml')->stringify);
      Args->initialize;
   }
}

################################################################################
# Public Method
################################################################################
sub test_01_constructor {
   my $test = shift;
   
   my $builder = $test->test_destnBuilder;
   
   has_attribute_ok($builder,'destnContent', 'Has a "destnContent" attribute');
   has_attribute_ok($builder,'destnPage', 'Has a "destnPage" attribute');

   has_method_ok($builder,'start_element','end_element','characters');
}

################################################################################
# Public Method
################################################################################
sub test_construct_with_default_destn_content {
   my $test = shift;
   
   my $destPg = DestnPage->new(
      templateConfig => Path::Class::File->new($FindBin::Bin,'..','cfg','Template.cfg')->resolve
   );

   my $builder;
   lives_ok {$builder = $test->class_name->new(destnPage => $destPg) } 'Instantiate object with default for DestnContent';
   is($builder->destnContent->destinations->file,Args->instance->destinations,
      'destinations attribute defaulted with correct argument for destinations file');
}

################################################################################
# Public Method
################################################################################
sub test_destination_page_generation {
   my $test = shift;
   
   my $builder = $test->test_destnBuilder;
   my $parsr = XML::SAX::ParserFactory->parser(Handler => $builder);
   lives_ok { $parsr->parse_uri(Path::Class::File->new($test->dataDir,'taxo_test.xml')->stringify) }
      'destination pages generated';
}

################################################################################
# Public Method
################################################################################
sub test_badly_formed_xml {
   my $test = shift;
   
   my $builder = $test->test_destnBuilder;
   my $parsr = XML::SAX::ParserFactory->parser(Handler => $builder);
   dies_ok { $parsr->parse_uri(Path::Class::File->new($test->dataDir,'taxo_missing_end_elems.xml')->stringify) }
      'Unbalanced Taxonomy xml with missing ending element tags throws exception';
   dies_ok { $parsr->parse_uri(Path::Class::File->new($test->dataDir,'taxo_too_many_end_elems.xml')->stringify) }
      'Unbalanced Taxonomy xml with too many ending element tags throws exception';
}

################################################################################
# Public Method
# Automatically called after every test method
################################################################################
sub test_teardown {
   my $test = shift;

   $test->next::method;
   $test->_testPath->rmtree()
      if (-d $test->_testPath);
   if ($test->test_report->current_method->name =~ /test_construct_with_default_destn_content/) {
      $test->restoreArgv();
      Args->clear;
   }
}

################################################################################
# Private Method _setTestCases
# Builder method for setting the private attribute _testPath
################################################################################
sub _set_testPath {
   my $test = shift;
   
   return(Path::Class::Dir->new($test->dataDir,'destinations'));
}

__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;