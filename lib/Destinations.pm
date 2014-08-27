################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package Destinations;

use English;
use warnings;
use IO::File;
use Moose;
use MooseX::Privacy;
use Try::Tiny;
use XML::DOM;

our $VERSION = '0.10';

with 'Role::PathClassable';
with 'Role::Notifiable';

################################################################################
# Attributes:
################################################################################

has 'file' => (isa => 'fileType',
   is => 'rw',
   required => 1,
   coerce => 1,
   lazy => 1,
   builder => '_setFileFromArgs',
   documentation => q/Full name of the destinations xml file/
);

has 'encoding' => (isa => 'Str',
   is => 'rw',
   default => '',
   documentation => q/Encoding format of xml file (generally utf8). Automatically set when the xml is read./
);

has '_fh' => (isa => 'IO::File',
   is => 'rw',
   traits => ['Private'],
   default => sub {IO::File->new},
   documentation => q/file handle to the Destinations xml file/
);

has '_indexes' => (isa => 'HashRef',
   is => 'rw',
   traits => ['Private'],
   default => sub {{}},
   documentation => q/Indexing of offsets to each destination record in the destinations file, based on the atlas id./
);

################################################################################
# Constructor:
# As part of instantiation, open the file handle to the destinations xml file,
# and build an index to each record within the xml, for fast access.
################################################################################
sub BUILD {
   my $self = shift;

   $self->echo('New Destinations Object instantiated');
   $self->_fh->open($self->file,'<') ||
      $self->exception('Failed to open the Destinations file');
   $self->_buildIndex();

} #BUILD

################################################################################
# Public Method
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
   #store default record separator...
   my $default_sep = $INPUT_RECORD_SEPARATOR;
   #Reposition to the exact location of the XML record, with that Atlas ID...
   $fh->seek($self->_indexes->{$atlas_id}{offset},0);
   #...and read the record in one go by changing the input record separator
   $INPUT_RECORD_SEPARATOR = "</destination>";
   my $recStr = $fh->getline;
   #Change input record separator back to it's default
   $INPUT_RECORD_SEPARATOR = $default_sep;
   
   my $domRec;
   try {
      my $parser = XML::DOM::Parser->new();
      $domRec = $parser->parse($recStr);
   } catch {
      $self->exception('Invalid XML Record parsed ['.$atlas_id.']: '.$_);
   };
   return($domRec);
}

################################################################################
# Public Method
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
# Private Method
# Ensure that the file is an XML file, and has an XML declaration. If encoding
# is given in the declaration, switch to use that encoding.
################################################################################
private_method _checkXMLDecl => sub {
   my $self = shift;
   my $fh = $self->_fh;

   while (!$fh->eof) {
      my $line = $fh->getline;
      next if ($line =~ /^\s*$/); #not interested in blank lines
      
      #first non-blank line is expected to be an xml declaration
      if ($line =~ /<\?xml.*?>/) {
         my ($enc) = $line =~ /encoding="(.+?)"/;
         if ($enc) {
            #Found xml encoding..., change to read encoding
            #change read mode to bin mode encoding i.e. decode utf8 etc
            $self->echo('Switching to read the xml file using '.$enc.' encoding.');
            $fh->binmode(':encoding('.uc($enc).')');
            $self->encoding(uc($enc));
         }
         last;
      } else {
         $self->exception('Missing XML declaration in ['.$self->file->basename.']');
      }
   }
};

################################################################################
# Private Method
# Called by _buildIndex to extract the attributes from the destination element
# and store it in the index.
################################################################################
private_method _setIndexDtls => sub {
   my $self = shift;
   my ($line) = @_;
   
   #extract attributes from the destination element
   my ($atlas_id) = $line =~ /\satlas_id="(\d+)"/;
   chomp($line);
   $self->exception('destination record "'.$line.'" element appears to be missing attribute "atlas_id"','error')
      if (!$atlas_id);
   $self->exception('atlas id ['.$atlas_id.'] is not unique in ['.$self->file->basename.']')
      if (exists($self->_indexes->{$atlas_id}));
   my ($title) = $line =~ /\stitle="(.+?)"/;
   $self->exception('Element node for destination record with atlas id ['.$atlas_id.'] appears to be missing attribute "title"','error')
       if (!$title);
   my ($title_ascii) = $line =~ /\stitle-ascii="(.+?)"/;
   $self->exception('Element node for destination record with atlas id ['.$atlas_id.'] appears to be missing attribute "title-ascii"','error')
      if (!$title_ascii);
   #Each index will store the attributes of each destination element, and the offset into the file
   $self->_indexes->{$atlas_id} = {title => $title, title_ascii => $title_ascii};
   return($self->_indexes->{$atlas_id});
};

################################################################################
# Private Method
# Build an index into the Destinations record, so we can extract a record
# without rereading the file from scratch, every time.
################################################################################
private_method _buildIndex => sub {
   my $self = shift;
   my $fh = $self->_fh;

   $self->echo('Building the index for ['.$self->file->basename.']');
   $self->_checkXMLDecl();
   my $pos = $fh->tell;
   my $inRecord = 0; #toggle when we reach start & ending destination element tags.
   while (!$fh->eof) {
      my $line = $fh->getline;
      if ($line =~ /<destination\s.*?>/) {
         $self->exception('Unmatched destination start element tag in ['.$self->file->basename.']')
            if ($inRecord);
         $inRecord = 1;
         #Create and add the offset to the index
         $self->_setIndexDtls($line)->{offset} = $pos;
      } elsif ($line =~ /<\/destination>/) {
         $self->exception('Unmatched destination closing element tag in ['.$self->file->basename.']')
            if (!$inRecord);
         $inRecord = 0;
      }
      $pos = $fh->tell;
   } #while
   $self->exception('No destination records found in ['.$self->file->basename.']')
      if (!keys(%{$self->_indexes}));
}; #_buildIndex

################################################################################
# Private Method
# Will automatically set the path from the Args object, if it wasn't passed
# through in the construction.
################################################################################
sub _setFileFromArgs {
   my $self = shift;

   $self->echo('Destinations XML not passed through as an argument during
      instantiation. Attempting to automatically set it from the Command Line arguments');
   return(Args->instance()->destinations)
      if (Args->initialised);
}


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
    
  or if Args.pm is used
  
  use Destinations;
  use Args;
  
  Args->initialize();
  my $destn = Destinations->new();

=head1 DESCRIPTION

Destinations works by opening the xml file, and creating an index into the file
during instantiation. This avoids reading in the whole file (which could potentially
be huge), and provides a fast method for accessing records as required.

When a record is required, it will be read from the file and returned as an XML DOM
object.

=head1 ATTRIBUTES

=head2 file

  Data Type:   Path::Class::File
  Required:    Yes

Full name of the destinations xml file. Will accept the name as a String.

= head2 encoding

  Data Type:  String
  Required:   Yes (see description)

Encoding format of xml file (generally utf8). Automatically set when the xml file is read.

=head1 METHODS

=head2 getDestination

Returns an XML DOM object of the destination record, for an atlas id.

  $dest_rec = $destn->getDestination(atlas_id)

= head2 destinationTitles

Returns the title information for an atlas id, stored in the index.

  $titledtls = $destn->destinationTitles(atlas_id)

$titledtls is a reference to hash, containing 'title' and 'title_ascii'

=cut
