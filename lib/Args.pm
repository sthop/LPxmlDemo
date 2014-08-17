################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package Args;

use English;
use warnings;
use Getopt::Long;
use List::Util qw/first/;
use MooseX::Singleton;
use MooseX::Privacy;

################################################################################
# Attributes:
################################################################################
has 'destinations' => (isa => 'Str',
   is => 'ro',
   required => 1,
   documentation => q/destinations xml file/
);

has 'taxonomy' => (isa => 'Str',
   is => 'ro',
   required => 1,
   documentation => q/taxonomy xml file/
);

has 'path' => (isa => 'Str',
   is => 'ro',
   required => 1,
   documentation => q/full path for the location of the generated html pages/
);

has 'verbose' => (isa => 'Bool',
   is => 'ro',
   default => 0,
   documentation => q/verbose mode/
);

################################################################################
# Constructor:
################################################################################
around BUILDARGS => sub {
   my $orig = shift;
   my $class = shift;
   
   my %args;
   GetOptions(\%args,'taxonomy|t=s','destinations|d=s','path|p=s','verbose|v', 'help|h')
      || $class->_usage();
   $class->_usage if (exists($args{help}));
   my $args = $class->$orig(%args);
   $class->_requiredArgs($args);
   
   return $args;
};

################################################################################
# Public Method getDestination
################################################################################
sub initialised {
   my $self = shift;
   return($self->meta->existing_singleton);
}

################################################################################
# Public Method getDestination
################################################################################
sub clear {
   my $self = shift;
   return($self->_clear_instance);
}


################################################################################
# Private Method getDestination
################################################################################
sub _usage {
   my $self = shift;
   my ($msg) = @_;
   
   print STDERR <<"EOT";
Generates html pages related to travel destinations around the world.

$0 [options]

 Options:
   -d, --destinations <destination xml> - destinations xml file
   -t, --taxonomy <taxonomy xml>        - taxonomy xml file
   -p, --path <path>                    - full path for the location of the generated html pages
   -v, --verbose                        - (optional) verbose mode
   -h, --help                           - Display this help message

$msg
EOT
   exit(1);
}

################################################################################
# Private Method getDestination
################################################################################
private_method '_requiredArgs' => sub {
   my $class = shift;
   my ($args) = @_;
   
   my $meta = $class->meta;
   foreach ($meta->get_attribute_list) {
      my $attrib = $meta->get_attribute($_);
      if ($attrib->is_required) {
         $class->_usage('ERROR! missing option --'.$_)
           if (!exists($args->{$_}));
      }
   }
};


no Moose;

################################################################################
1;
__END__
