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

our $VERSION = '0.10';

with 'Role::Notifiable';

################################################################################
# Attributes:
################################################################################
has 'destinations' => (isa => 'Str',
   is => 'ro',
   required => 1,
   documentation => q/The destinations xml file (including path)/
);

has 'taxonomy' => (isa => 'Str',
   is => 'ro',
   required => 1,
   documentation => q/The taxonomy xml file (including path)/
);

has 'path' => (isa => 'Str',
   is => 'ro',
   required => 1,
   documentation => q/Full path for the location of the generated html pages/
);

has 'verbose' => (isa => 'Bool',
   is => 'ro',
   default => 0,
   documentation => q/Verbose mode/
);

################################################################################
# Constructor:
# Instantiate the object, using GetOptions to parse the command line
# arguments.
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

sub BUILD {
   my $self = shift;
   my $args = $0." called with:\n\ttaxonomy - ".$self->taxonomy."\n\tdestinations - ";
   $args .= $self->destinations."\n\tpath - ".$self->path;
   $args .= "\n\tverbose mode" if ($self->verbose);

   $self->echo($args);
}

################################################################################
# Public Method getDestination
# Returns whether the singleton object has been initialised
################################################################################
sub initialised {
   my $self = shift;
   return($self->meta->existing_singleton);
}

################################################################################
# Public Method getDestination
# Clears the singleton instance, so that it can be reinitialised if required.
################################################################################
sub clear {
   my $self = shift;
   return($self->_clear_instance);
}

################################################################################
# Private Method getDestination
# Called if during instantiation, it found that the command line arguments were
# not correct, or the 'help' option was in the arguments
################################################################################
sub _usage {
   my $self = shift;
   my ($msg) = @_;
   
   print STDERR <<"EOT";
Generates html pages related to travel destinations around the world.

$0 [options]

 Options:
   -d, --destinations <destination xml> - The destinations xml file (including path)
   -t, --taxonomy <taxonomy xml>        - The taxonomy xml file (including path)
   -p, --path <path>                    - full path for the location of the generated html pages
   -v, --verbose                        - (optional) verbose mode
   -h, --help                           - Display this help message

$msg
EOT
   exit(1);
}

################################################################################
# Private Method getDestination
# Checks for any missing options that are required
################################################################################
private_method '_requiredArgs' => sub {
   my $class = shift;
   my ($args) = @_;
   
   my $meta = $class->meta;
   #loops through all the class' attributes
   foreach ($meta->get_attribute_list) {
      my $attrib = $meta->get_attribute($_);
      #if the attribute is required, check to see that the command line argument
      #was passed in.
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

=head1 NAME

Args - A singleton class for storing the command line arguments

=head1 SYNOPSIS

  use Args;
  
  #initialise
  my $args = Args->initialize();
  
  #get an instance
  my $args = Args->instance();
  
  #Check if Args has been initialised
  if (Args->initialised()) {
     #Args has already been initialised
  }
  
  #clear the object (will no longer be initialised)

=head1 DESCRIPTION

The Args singleton class stores the command line arguments, so that they are
easily accessible anywhere within the application. This allows hiding and
automation of some of the class construction. Under the hood, it uses Getopt::Long
to parse the command line arguments.

These attributes are read only, as they are supposed to reflect the original command
line arguments.

=head1 ATTRIBUTES

=head2 destinations

  Data Type:   Str
  Required:    Yes

The destinations xml file (including path).

=head2 taxonomy

  Data Type:   Str
  Required:    Yes

The taxonomy xml file (including path).

=head2 path

  Data Type:   Str
  Required:    Yes

Full path for the location of the generated html pages.

=head2 verbose

  Data Type:   Str
  Required:    No

Verbose mode.

=head1 METHODS

=head2 initialize

Comes from and is provided by the MooseX::Singleton class, and is used to initialise
the instance of the class.

  my $args = Args->initialize();

=head2 instance

Comes from and is provided by the MooseX::Singleton class to get the instance of the
object.

  my $args = Args->instance();

=head2 initialised

As the author of MooseX::Singleton didn't seem to think it necessary to provide a method
to query whether the singleton class has been initialised, it has been provided here by
digging under the hood of MooseX::Singleton.

   my $args = (Args->initialised()) ? Args->instance() : Args->initialize();

=head2 clear

In certain instances, it may be useful to clear and reinitialise the instance of the
class. The author of MooseX::Singleton didn't seem to think this was necessary, so again it
has been provided here by digging under the hood and supplying what is a private method in
MooseX::Singleton, as a public method here.

   Args->clear();

=cut