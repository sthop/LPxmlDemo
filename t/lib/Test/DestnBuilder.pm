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
use XML::SAX::ParserFactory;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Destinations;
use DestnContent;
use DestnPage;

with 'Test::Class::Moose::Role::AutoUse';

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
   my $destPg = DestnPage->new(path => Path::Class::Dir->new($test->dataDir,'destinations'),
      templateConfig => Path::Class::File->new($FindBin::Bin,'..','cfg','Template.cfg')->resolve
   );
   $test->test_destnBuilder(
      $test->class_name->new(destnContent => $destContent, destnPage => $destPg)
   );
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

__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;