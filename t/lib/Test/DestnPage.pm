################################################################################
# Author: Sten Hopkins
################################################################################

package Test::DestnPage;

use English;
use warnings;
use FindBin;
use Path::Class;
use Test::Class::Moose;
use Test::Moose::More;
use MooseX::Privacy;
use utf8;
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Args;

with 'Test::Class::Moose::Role::AutoUse';
with 'Role::Argv';

################################################################################
# Attributes:
################################################################################

has 'test_destnPage' => (isa => 'DestnPage',
   is => 'rw',
   documentation => q/DestnPage object used for the tests/
);

has 'dataDir' => (isa => 'Path::Class::Dir',
   is => 'rw',
   default => sub {Path::Class::Dir->new($FindBin::Bin,'Data')},
   documentation => q/Data dir for files used in the tests/
);

################################################################################
# Public Method
# Authomatically called at start of test DestnPage class
################################################################################
sub test_startup {
   my $test = shift;
   
   $test->next::method;
   $test->test_destnPage(
      $test->class_name->new(path => $test->dataDir, encoding => 'UTF-8',
         templateConfig => Path::Class::File->new($FindBin::Bin,'..','cfg','Template.cfg')->resolve)
   );
}

################################################################################
# Public Method
# Authomatically called before each test method
################################################################################
sub test_setup {
   my $test = shift;
   
   $test->next::method;
   if ($test->test_report->current_method->name eq 'test_generating_html_not_using_utf8') {
      #Set up destination Page to not use UTF-8 encoding
      $test->test_destnPage->encoding('');
   } elsif ($test->test_report->current_method->name eq 'test_invalid_path_for_generated_html') {
      $test->test_destnPage->path('/invalid/path');
   } elsif ($test->test_report->current_method->name =~ /defaulting_path/) {
      $test->alterArgv('-t' => 'dummy_taxonomy', '-d' => 'dummy_destination', '-p' => 'dummy_path');
      Args->initialize;
   }
}

################################################################################
# Public Method
################################################################################
sub test_00_constructor {
   my $test = shift;
   
   my $page = $test->test_destnPage;
   does_ok($page,'Role::PathClassable', 'does Role PathClassable which allows coercing of string into Path::Class::File/Dir type');
   does_ok($page,'Role::Notifiable', 'does Role Notifiable');
   has_attribute_ok($page,'path', 'Has a "path" attribute');
   has_attribute_ok($page,'templateConfig', 'Has a "templateConfig" attribute');
   has_attribute_ok($page,'encoding', 'Has an "encoding" attribute');
   has_method_ok($page,'generate');
}

################################################################################
# Public Method
################################################################################
sub test_instantiation_with_defaulting_path_from_args {
   my $test = shift;
   
   my $destPage;
   lives_ok { $destPage = $test->class_name->new(
      templateConfig => Path::Class::File->new($FindBin::Bin,'..','cfg','Template.cfg')->resolve)
   } 'Instantiate defaulting path from args';
   is ($destPage->path,'dummy_path','path contains value from command line args');
}

################################################################################
# Public Method
################################################################################
sub test_generating_html_page {
   my $test = shift;

   my $page = $test->test_destnPage;
   my $content = $test->_pageContentData();
   lives_ok { $page->generate($content) } 'Generate html page';
   ok(-e Path::Class::File->new($test->dataDir,$content->{node_id}.'.html'),'and file exists');
}

################################################################################
# Public Method
################################################################################
sub test_generating_html_not_using_utf8 {
   my $test = shift;
   
   my $page = $test->test_destnPage;
   my $content = $test->_pageContentData();
   warning_like { $page->generate($content) } qr/Wide character in print/, 'Generate html page without utf8 encoding throws Wide character in print warning';
}

################################################################################
# Public Method
################################################################################
sub test_invalid_path_for_generated_html {
   my $test = shift;

   my $page = $test->test_destnPage;
   my $content = $test->_pageContentData();
   dies_ok {$page->generate($content)} 'Invalid path provided throws exception';
}

################################################################################
# Public Method
################################################################################
sub test_invalid_missing_template_config {
   my $test = shift;

   my $page;
   lives_ok { $page = $test->class_name->new(path => $test->test_destnPage->path,
      encoding => $test->test_destnPage->encoding,
      templateConfig => 'missing.cfg') } 'instantiate destination page with missing template config';
   my $content = $test->_pageContentData();
   dies_ok {$page->generate($content)} 'missing config throws exception';
   lives_ok { $page = $test->class_name->new(path => $test->test_destnPage->path,
      encoding => $test->test_destnPage->encoding,
      templateConfig => Path::Class::File->new($test->dataDir,'destntest.xml')) } 
      'instantiate destination page with invalid template yaml config';
   dies_ok {$page->generate($content)} 'invalid config throws exception';
}

################################################################################
# Public Method
################################################################################
sub test_missing_required_field_for_generating_html_page {
   my $test = shift;
   
   my $page = $test->test_destnPage;
   my $content = $test->_pageContentData();
   delete($content->{content});
   throws_ok { $page->generate($content) } qr/undefined variable: content/,
      'generating html with missing fields throws exception';
}

################################################################################
# Public Method
# Automatically called after every Test method.
################################################################################
sub test_teardown {
   my $test = shift;

   $test->next::method;
   if ($test->test_report->current_method->name =~ /^test_generating_html_page/) {
      #This test method generated a file, which now has to be cleaned up and removed
      my $data = $test->_pageContentData;
      my $testHtml = Path::Class::File->new($test->dataDir,$data->{node_id}.'.html');
      unlink($testHtml) if (-e $testHtml);
   }
   if ($test->test_report->current_method->name eq 'test_generating_html_not_using_utf8') {
      #Set up destination Page back to using UTF-8 encoding
      $test->test_destnPage->encoding('UTF-8');   
   } elsif ($test->test_report->current_method->name eq 'test_invalid_path_for_generated_html') {
      $test->test_destnPage->path($test->dataDir);
   } elsif ($test->test_report->current_method->name =~ /defaulting_path/) {
      $test->restoreArgv();
      Args->clear;
   }
}

################################################################################
# Public Method
################################################################################
private_method '_pageContentData' => sub {
   my $test = shift;

   return({node_id => 'dummy_test', content => {}, navigation => [], title => 'Dummy - ö조'});
};


__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################

1;
