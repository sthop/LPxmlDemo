################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package Destinations;

use English;
use warnings;
use IO::File;
use Moose;
use XML::DOM;

with 'Role::PathClassable';
with 'Role::Notifiable';

################################################################################
# Attributes:
################################################################################

has 'file' => (isa => 'fileType',
   is => 'rw',
   required => 1,
   coerce => 1,
   documentation => q/Full name of the destinations xml file/
);

has 'encoding' => (isa => 'Str',
   is => 'rw',
   default => '',
   documentation => q/encoding format of xml file (generally utf8)/
);

has '_fh' => (isa => 'IO::File',
   is => 'rw',
   default => sub {IO::File->new},
   documentation => q/file handle to the xml file/
);

has '_indexes' => (isa => 'HashRef',
   is => 'rw',
   default => sub {{}},
   documentation => q/Indexing of offsets to each destination record in the destination file, based on the atlas id./
);
   


################################################################################
# Constructor:
################################################################################
sub BUILD {
   my $self = shift;

   $self->_fh->open($self->file,'<') ||
      $self->exception('Failed to open the Destinations file');
   $self->echo('Generating Destination Record index into ['.$self->file->basename.']');
   $self->_buildIndex();

} #BUILD

################################################################################
# Public Methods getDestination
#
################################################################################
sub getDestination {
   my $self = shift;
   my ($atlas_id) = @_;

   my $fh = $self->_fh;

   #The Atlas ID passed in, isn't indexed
   return(undef) if (!exists($self->_indexes->{$atlas_id}));
   
   #File should have been opened during instantiation, so try reopening, if it's closed
   if (!$fh->opened) {
      $self->warning('Destinations file should already be open! Attempting to reopen');
      $fh->open($self->file,'<') ||
         $self->exception('Failed to reopen the Destinations file');
   }
   
   #Reposition to the exact location of the XML record, with that Atlas ID...
   $fh->seek($self->_indexes->{$atlas_id}{offset},0);
   #...and read the record in one go
   $INPUT_RECORD_SEPARATOR = "</destination>";
   my $recStr = $fh->getline;
   $INPUT_RECORD_SEPARATOR = "\n";
   
   my $parser = XML::DOM::Parser->new();
   return($parser->parse($recStr));
}

################################################################################
# Public Methods getDestination
#
################################################################################
sub destinationTitles {
   my $self = shift;
   my ($atlas_id) = @_;

   #The Atlas ID passed in, isn't indexed
   return(undef) if (!exists($self->_indexes->{$atlas_id}));
   my %destTitles = %{$self->_indexes->{$atlas_id}};
   delete($destTitles{offset});
   return(\%destTitles);
}

################################################################################
# Private Method _posStartDestRec
# Returns the file offset position of the start of each destination record.
################################################################################
sub _posStartDestRec {
   my $self = shift;
   my $fh = $self->_fh;
   my $pos = $fh->tell;

   #find start location of the next destination record
   while (!$fh->eof) {
      my $line = $fh->getline;
      if (my ($enc) = $line =~ /<\?xml.+encoding="(.+?)"/) {
         #While finding start position of Record, found xml encoding..., change to read encoding
         $fh->binmode(':encoding('.uc($enc).')');
         $self->encoding(uc($enc));
      }
      if ($line =~ /<destination.+?atlas_id="\d+"/) {
         $fh->seek($pos,0);
         return($pos);
      }
      $pos = $fh->tell;
   } #while
   return(undef); #undef mean we've reached eof
} #_posStartDestRec

################################################################################
# Private Method _buildIndex
# Build an index into the Destinations record, so we can extract a record when
# and as required.
################################################################################
sub _buildIndex {
   my $self = shift;
   my $fh = $self->_fh;

   my $rec = 0;
   while (!$fh->eof) {
      #Get file offset position of the start of each destination record
      my $pos = $self->_posStartDestRec();
      next if (!defined $pos);
      $rec++;
      #change the input record separator, so we can read in the entire record in one hit
      $INPUT_RECORD_SEPARATOR = "</destination>";
      my $line = $fh->getline;
      $INPUT_RECORD_SEPARATOR = "\n"; #Change input record separator back to it's default
      my ($atlas_id) = $line =~ /<destination.+?atlas_id="(\d+)"/;
      $self->exception('destination record No ['.$rec.'] - element appears to be missing attribute "atlas_id"','error')
         if (!$atlas_id);
      $self->exception('['.$atlas_id.'] is not unique at Record ['.$rec.']')
         if (exists($self->_indexes->{$atlas_id}));
      my ($title) = $line =~ /title="(.+?)"/;
      my ($title_ascii) = $line =~ /title-ascii="(.+?)"/;
      $self->_indexes->{$atlas_id} =
         {title => $title, title_ascii => $title_ascii, offset => $pos};
   } #while
} #_buildIndex


__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;
__END__

=head1 NAME

Destinations - Class for accessing and parsing records in the Destinations XML file.

=head1 SYNOPSIS

  use Destinations;
  my $destn = Destinations->new(file => 'destinations file');

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 file

  Data Type:   Path::Class::Dir
  Required:    Yes

Full name of the destinations xml file. Will accept the name as a String.

=cut