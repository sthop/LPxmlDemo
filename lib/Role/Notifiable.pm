################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package Role::Notifiable;

use English;
use warnings;
use Carp qw(carp croak);
use List::Util qw/first/;
use Log::Log4perl;
use Moose::Role;
use Path::Class;

our $VERSION = sprintf("%d.%02d", q'$Revision: 1.1 $' =~ /(\d+)\.(\d+)/);

################################################################################
# Attributes:
################################################################################
#...

has 'logger' => (isa => 'Log::Log4perl::Logger',
   is => 'rw',
   required => 0,
   predicate => 'has_logger',
   documentation => q/A Log4perl logger/
);

has 'loggerCategory' => (isa => 'Str',
    is => 'rw',
    default => '',
    documentation => q/This is a Logger Category, required for getting a Log4perl logger/
);

################################################################################
# Private Methods echo
# echo a message to either STDIO or logger, depending on requirements
################################################################################
sub echo {
   my $self = shift;
   my ($message, $level) = @_;
   
   $level = 'info'
      if ( !defined $level ||
         !(first {$level eq $_} qw/trace debug info warn error fatal/) );
   if ($self->has_logger) {
      $self->logger->$level($message);
   } else {
      print STDOUT $message."\n";
   }
}

################################################################################
# Private Methods echo
# Message out a warning to either STDIO or logger, depending on requirements
################################################################################
sub warning {
   my $self = shift;
   my ($message, $level) = @_;
   
   $level = 'warn'
      if ( !defined $level ||
         !(first {$level eq $_} qw/trace debug info warn error fatal/) );
   if ($self->has_logger) {
      $self->logger->$level($message);
   }
   carp($message."\n");
}

################################################################################
# Private Methods echo
# Message out a warning to either STDIO or logger, depending on requirements
################################################################################
sub exception {
   my $self = shift;
   my ($message, $level) = @_;
   
   $level = 'fatal'
      if ( !defined $level ||
         !(first {$level eq $_} qw/trace debug info warn error fatal/) );
   if ($self->has_logger) {
      $self->logger->$level($message);
   }
   croak($message."\n");
}

################################################################################
before [qw/echo warning exception/] => sub {
   my $self = shift;
   
   if (Log::Log4perl->initialized() && !$self->has_logger) {
      $self->logger(Log::Log4perl->get_logger($self->loggerCategory));
   }
};

no Moose::Role;

################################################################################
1;
__END__