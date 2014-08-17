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

sub alterArgv {
   my $test = shift;
   @ARGV = @_;
}

sub restoreArgv {
   my $test = shift;
   @ARGV = @{$test->originalArgv};
}


sub _storeArgv {
   my $test = shift;
   
   my @orig = @ARGV;
   $test->originalArgv(\@orig);
}

no Moose::Role;

################################################################################
1;
__END__
