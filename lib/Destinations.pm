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
   documentation => q/Encoding format of xml file (generally utf8). Automatically set when the xml is read./
);

has '_fh' => (isa => 'IO::File',
   is => 'rw',
   default => sub {IO::File->new},
   documentation => q/file handle to the Destinations xml file/
);

has '_indexes' => (isa => 'HashRef',
   is => 'rw',
   default => sub {{}},
   documentation => q/Indexing of offsets (based on atlas_id) to each destination record in the destinations file, based on the atlas id./
);
   


################################################################################
# Constructor:
# As part of instantiation, open the file handle to the destinations xml file,
# and build an index to each record within the xml, for fast access.
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
# Extract the destination record for the atlas_id given, and return an XML DOM
# object of that record.
################################################################################
sub getDestination {
   my $self = shift;
   my ($atlas_id) = @_;

   my $fh = $self->_fh;

   $self->echo('Extracting and parsing Destination record for ['.$atlas_id.']','debug');

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
# Public Methods destinationTitles
# Return the title details stored in the index, for a particular atlas_id
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
         #This should only happen while looking for the first destination record.
         #change read mode to bin mode encoding i.e. decode utf8 etc
         $self->echo('Switching to read the xml file using '.$enc.' encoding.');
         $fh->binmode(':encoding('.uc($enc).')');
         $self->encoding(uc($enc));
      }
      
      #found start of destination record, reset file position to start of line
      #& return the position
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
# Build an index into the Destinations record, so we can extract a record
# without rereading the file from scratch, every time.
################################################################################
sub _buildIndex {
   my $self = shift;
   my $fh = $self->_fh;

   $self->echo('Building the index for ['.$self->file->basename.']');
   my $rec = 0;
   while (!$fh->eof) {
      #Get file offset position of the start of each destination record
      my $pos = $self->_posStartDestRec();
      next if (!defined $pos);
      $rec++;
      #change the input record separator, so we can read in the entire record in one block
      $INPUT_RECORD_SEPARATOR = "</destination>";
      my $line = $fh->getline;
      #Change input record separator back to it's default
      $INPUT_RECORD_SEPARATOR = "\n";
      
      #extract attributes from the destination element
      my ($atlas_id) = $line =~ /<destination.+?atlas_id="(\d+)"/;
      $self->exception('destination record No ['.$rec.'] - element appears to be missing attribute "atlas_id"','error')
         if (!$atlas_id);
      $self->exception('['.$atlas_id.'] is not unique at Record ['.$rec.']')
         if (exists($self->_indexes->{$atlas_id}));
      my ($title) = $line =~ /title="(.+?)"/;
      $self->exception('destination record No ['.$rec.'] - element appears to be missing attribute "title"','error')
         if (!$title);
      my ($title_ascii) = $line =~ /title-ascii="(.+?)"/;
      $self->exception('destination record No ['.$rec.'] - element appears to be missing attribute "title_ascii"','error')
         if (!$title_ascii);
      
      #Each index will store the attributes of each destination element, and the offset into the file
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

Destinations works by opening the xml file, and creating an index into the file
during instantiation. This avoids reading in the whole file (which could potentially
be huge), and provides a fast method for accessing records as required.

When a record is record, it will be read from the file and returned as an XML DOM
object.

=head1 ATTRIBUTES

=head2 file

  Data Type:   Path::Class::File
  Required:    Yes

Full name of the destinations xml file. Will accept the name as a String.

= head2 encoding

  Data Type:  String
  Required:   Yes (see description)

Encoding format of xml file (generally utf8). Automatically set when the xml is read.

=head1 METHODS

=head2 getDestination

Returns an XML DOM object of the destination record, for an atlas id.

  $dest_rec = $destn->getDestination(atlas_id)

= head2 destinationTitles

Returns the title information for an atlas id, stored in the index.

  $titledtls = $destn->destinationTitles(atlas_id)

$titledtls is a reference to hash, containing 'title' and 'title_ascii'

=cut