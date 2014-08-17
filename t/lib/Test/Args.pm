################################################################################
# Author: Sten Hopkins
################################################################################

package Test::Args;

use English;
use Getopt::Long;
use Test::Class::Moose;
use Test::Moose::More;
use MooseX::Privacy;
use Try::Tiny;

with 'Test::Class::Moose::Role::AutoUse';
with 'Role::Argv';

################################################################################
# Public Method
# Automatically called before each test method
################################################################################
sub test_setup {
   my $test = shift;
   
   $test->next::method;
   
   if ($test->test_report->current_method->name =~ /^test_01/) {
      $test->alterArgv(%{$test->_testArgs()});
      $test->class_name->initialize(); #instantiate singleton object of class Args
   }
}

################################################################################
# Public Method
################################################################################
sub test_01_constructor {
   my $test = shift;
   my $expected = _expectedValues();
   
   SKIP: {
      skip 'Args singleton class not already initialised'
         if (!ok($test->class_name->initialised,'Args singleton class initialized'));
      my $args = $test->class_name->instance;
      has_method_ok($args,'initialised','clear');
      for (keys %{$expected}) {
         next if (!has_attribute_ok($args,$_,'Has a "'.$_.'" attribute'));
         is($args->$_,$expected->{$_}, 'attribute "'.$_.'" has correct value');
      }
   }
}

################################################################################
# Public Method
# Automatically called after every test method
################################################################################
sub test_teardown {
   my $test = shift;
   
   $test->next::method;
   $test->restoreArgv();
   $test->class_name->clear;
}

################################################################################
# Private Method _capture_echo_message
# returns a hash containing expected Args attributes and values they should be
# set to.
################################################################################
private_method _expectedValues => sub {
   my $compare = {taxonomy => '-t', destinations => '-d', path => '-p'};
   my $args = _testArgs();
   for (keys %{$compare}) {
      $compare->{$_} = $args->{$compare->{$_}};
   }
   $compare->{verbose} = 0;
   return($compare);
};

################################################################################
# Private Method _testArgs
# returns a hash of pseudo command line arguments
################################################################################
private_method _testArgs => sub {
   return({'-t' => '/taxonomy/file', '-d' => '/destinations/file', '-p' => 'path/for/generated/html'});
};


__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################

1;
