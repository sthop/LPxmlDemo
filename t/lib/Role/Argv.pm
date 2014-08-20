################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package Role::Argv;

use English;
use warnings;
use Moose::Role;

################################################################################
# Attributes:
################################################################################
has 'originalArgv' => ( isa => 'ArrayRef',
   is => 'rw',
   builder => '_storeArgv'
);

################################################################################
# Public Method
# Alters the original command line arguments, for various unit tests that depend
# on command line arguments being set.
################################################################################
sub alterArgv {
   my $test = shift;
   @ARGV = @_;
}

################################################################################
# Public Method
# Restore the original command line argument, after the unit test has completed.
################################################################################
sub restoreArgv {
   my $test = shift;
   @ARGV = @{$test->originalArgv};
}


################################################################################
# Private Method
# Automatically initialises and store the original command line arguments.
################################################################################
sub _storeArgv {
   my $test = shift;
   
   my @orig = @ARGV;
   $test->originalArgv(\@orig);
}

no Moose::Role;

################################################################################
1;
__END__
