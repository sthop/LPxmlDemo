################################################################################
# Author: Sten Hopkins
################################################################################

package Test::DestnContent;

use English;
use warnings;
use FindBin;
use Path::Class;
use Test::Class::Moose;
use Test::Moose::More;
use MooseX::Privacy;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Destinations;
use utf8;

with 'Test::Class::Moose::Role::AutoUse';

################################################################################
# Attributes:
################################################################################

has 'test_destnContent' => (isa => 'DestnContent',
   is => 'rw',
   documentation => q/DestnContent object used for the tests/
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
# Public Method
# Automatically called at start of Test DestnContent class
################################################################################
sub test_startup {
   my $test = shift;
   
   $test->next::method;
   my $dest = Destinations->new(file => Path::Class::File->new($test->dataDir,'destntest.xml'));
   $test->test_destnContent(
      $test->class_name->new(destinations => $dest)
   );
}

################################################################################
# Public Method
################################################################################
sub test_00_constructor {
   my $test = shift;
   
   my $content = $test->test_destnContent;
   does_ok($content,'Role::Notifiable', 'does Role Notifiable');
   has_attribute_ok($content,'destinations', 'Has a "destinations" attribute');
   has_method_ok($content,'build');
}

################################################################################
# Public Method
################################################################################
sub test_build_content {
   my $test = shift;
   
   my $content = $test->test_destnContent;
   my $cases = $test->_testCases;
   
   foreach my $atlas_node_id (keys %{$cases}) {
      my $gotContent = {};
      ok($content->build($atlas_node_id,$gotContent),
         'build content for '.$atlas_node_id.' returns true');
      cmp_deeply($gotContent,$cases->{$atlas_node_id},
         'Content built correctly for atlas node id '.$atlas_node_id);
   }
}

################################################################################
# Public Method
################################################################################
sub test_build_content_with_invalid_node_id {
   my $test = shift;
   
   my $content = $test->test_destnContent;
   my $gotContent = {};
   
   ok(!$content->build('111111',$gotContent),
      'build for invalid node id returns false value');
   cmp_deeply($gotContent,{node_id => '111111', navigation => [], content=> {}},
      'Content contains mandatory fields (except title)');
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
   "355611" : {
      "node_id" : "355611",
      "title" : "South Africa",
      "title_ascii" : "South Africa",
      "navigation" : [],
      "content" : {
         "history" : {
            "detail" : ["In 1910 the Union of South Africa was created"],
            "overview" : "The earliest recorded inhabitants of this area of Africa were the San"
         },
         "introduction" : {
            "overview" : ["Travel Alert: Crime is a problem throughout South Africa"]
         }
      }
   },
   "355064" : {
      "node_id" : "355064",
      "title" : "Africaö",
      "title_ascii" : "Africa",
      "navigation" : [],
      "content" : {
         "history" : {
            "detail" : ["You’ve probably heard the claim that Africa"],
            "overview" : "African history is a massive and intricate subject"
         },
         "introduction" : {
            "overview" : ["How do you capture the essence of Africa"]
         }
      }
   },
   "355614" : {
      "node_id" : "355614",
      "title" : "Free State",
      "title_ascii" : "Free State",
      "navigation" : [],
      "content" : {
         "introduction" : {
            "overview" : ["This is a place where farmers in floppy hats and overalls"]
         }
      }
   },
   "355612" : {
      "node_id" : "355612",
      "title" : "Cape Town",
      "title_ascii" : "Cape Town",
      "navigation" : [],
      "content" : {
         "history" : {
            "detail" : ["Bush fires may be a natural part of Table Mountain's life cycle"],
            "overview" : "'Today, praise be the Lord, wine was pressed for the first time"
         },
         "introduction" : {
            "overview" : ["Good-looking, fun-loving, sporty and sociable"]
         }
      }
   }
}