################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package Role::Notifiable;

use English;
use warnings;
use Carp qw(cluck confess longmess);
use List::Util qw/first/;
use Log::Log4perl;
use Moose::Role;
use Path::Class;
use Args;

our $VERSION = '0.10';

################################################################################
# Attributes:
################################################################################
#...
has 'logger' => (isa => 'Log::Log4perl::Logger',
   is => 'rw',
   required => 0,
   predicate => 'has_logger',
   documentation => q/A Log4perl logger, will be automatically set if Log4perl has been initialised/
);

has 'loggerCategory' => (isa => 'Str',
    is => 'rw',
    default => '',
    documentation => q/This is a Logger Category, required for getting a Log4perl logger/
);

################################################################################
# Public Method echo
# echo a message to logger, if logger has been initialised, and to STDOUT, if
# verbose mode flag was used on the command line.
################################################################################
sub echo {
   my $self = shift;
   my ($message, $level) = @_;
   
   $level = 'info'
      if ( !defined $level ||
         !(first {$level eq $_} qw/trace debug info warn error fatal/) );
   if ($self->has_logger) {
      $self->logger->$level($message);
   } 
   
   #If verbose option given on the command line, print echo statements to STDOUT
   print STDOUT $message."\n"
      if (Args->initialised && Args->instance->verbose);
}

################################################################################
# Public Method warning
# Message out a warning to either STDIO or logger, depending on requirements
################################################################################
sub warning {
   my $self = shift;
   my ($message, $level) = @_;
   
   $level = 'warn'
      if ( !defined $level || !(first {$level eq $_} qw/warn error/) );
   my $prefix = ($level eq 'warn') ? 'WARNING! ' : 'ERROR! ';
   $message = $prefix.$message;

   if ($self->has_logger) {
      if ($level eq 'warn') {
         $self->logger->logcluck($message);
      } else {
         $self->logger->error_warn(longmess($message));   
      }
   } else {
      cluck($message,"\n");
   }
}

################################################################################
# Public Method exception
# Message out a warning to either STDIO or logger, depending on requirements
################################################################################
sub exception {
   my $self = shift;
   my ($message, $level) = @_;
   
   $level = 'fatal'
      if ( !defined $level || !(first {$level eq $_} qw/error fatal/) );
   my $prefix = ($level eq 'fatal') ? 'FATAL! ' : 'ERROR! ';
   $message = $prefix.$message;
   
   if ($self->has_logger) {
      if ($level eq 'fatal') {
         $self->logger->logconfess($message);
      } else {
         $self->logger->error_die(longmess($message));
      }
   } else {
      confess($message."\n");
   }
}

################################################################################
# before method call
# Detects if log4perl has been initialised (used), and retrieves the logger,
# setting the logger attribute.
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

=head1 NAME

Role::Notifiable - Adds echo / warning and Exception method to the class using the role.

=head1 SYNOPSIS

  use Moose;
  
  with 'Role::Notifiable';
  
  $self->echo('echo message');
  $self->warning('warning message');
  $self->exception('exception message');
  $self->echo('debug level echo message','debug');
  $self->warning('error level warning message','error');
  $self->exception('error level exception message,'error');

=head1 DESCRIPTION

Provides utilities for handling various messaging and logging requirements. It will
handle logging, using log4perl (based on Java's log4j), if it's being used, and printing
messages to the screen, if required.

=head1 ATTRIBUTES

=head2 logger

  Data Type:   Log::Log4perl::Logger
  Required:    No

A Log4perl logger, will be automatically set if Log4perl has been initialised

=head2 loggerCategory

  Data Type:   String
  Required:    No

This is a Logger Category, required for getting a Log4perl logger

=head1 METHODS

=head2 echo

Will echo messages to the screen in verbose mode, and log a "info" level message, if
logging is being done.

  $self->echo('message',$level);

$level can either be 'trace', 'debug', 'info', 'warn', 'error', 'fatal'. Default is 'info'.

=head2 warning

Will generate a warning and log a "warn" level message, if logging is being done.

  $self->echo('message',$level);

$level can either be 'warn' or 'error'. Default is 'warn'.

=head2 exception

Will generate an exception and log a "fatal" level message, if logging is being done.

  $self->echo('message',$level);

$level can either be 'error' or 'fatal'. Default is 'fatal'.

=cut
