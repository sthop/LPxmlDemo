################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package Role::PathClassable;

use English;
use warnings;
use Moose::Role;
use Moose::Util::TypeConstraints;
use Path::Class;

our $VERSION = sprintf("%d.%02d", q'$Revision: 1.1 $' =~ /(\d+)\.(\d+)/);

################################################################################
# Object Attribute Sub Types:
################################################################################
#...

subtype 'pathType' => as 'Path::Class::Dir';

coerce 'pathType' =>
   from 'Str' =>
   via {
      my $path = Path::Class::Dir->new($_);
      $path;
   };

subtype 'fileType' => as 'Path::Class::File';

coerce 'fileType' =>
   from 'Str' =>
   via {
      my $file = Path::Class::File->new($_);
      $file;
   };

################################################################################
# Methods

no Moose::Role;

1;
__END__