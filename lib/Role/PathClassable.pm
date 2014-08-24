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

our $VERSION = '0.10';

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

=head1 NAME

Role::PathClassable - Adds subtypes for Path and File attributes, to the class using
the role.

=head1 SYNOPSIS

  use Moose;
  
  with 'Role::PathClassable';
  
  has 'somePath' => (isa => 'pathType',
     is => 'rw',
     coerce => 1
  );
  
  has 'someFile' => ( isa => 'fileType',
     is => 'rw',
     coerce => 1
  );

=head1 DESCRIPTION

Allows attributes of class type 'Path::Class::Dir', or 'Path::Class::File' to be
initialised with a String. Strings will be automatically converted to an object of
the specified class.

=cut