################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package DestnContent;

use English;
use warnings;
use Moose;
use Destinations;

with 'Role::Notifiable';

################################################################################
# Attributes:
################################################################################

has 'destinations' => (isa => 'Destinations',
   is => 'rw',
   required => 1,
   builder => '_set_destinations',
   documentation => q/Destinations object/
);

################################################################################
# Public Method
# Build up the content for displaying on a destination html page, adding it to
# the $pageData Hash.
################################################################################
sub build {
   my $self = shift;
   my ($node_id, $pageData) = @_;
   
   #Add main keys (template fields), expected by the destinations.html
   $pageData->{node_id} = $node_id; #will be used for the html file name, and for generating navsj
   $pageData->{content} = {};       #main content hash
   $pageData->{navigation} = [];    #initialise navigation list
   
   #get the destination document & if not found, return
   my $doc = $self->destinations->getDestination($node_id);
   return if (!defined($doc));
   
   $self->echo('Collecting Details for "'.
      $self->destinations->destinationTitles($node_id)->{title_ascii}
      .'" - atlas node id "'.$node_id.'"');

   #Add document data to the page contents
   $self->echo('Adding Title information to content','debug');
   $self->_setTitles($pageData,$doc);
   
   #loop through each child element of <destination>
   foreach my $node (@{$doc->getDocumentElement->getChildNodes}) {
      next if ($node->getNodeType != $node->ELEMENT_NODE);
      if ($node->getTagName eq 'history') {
         $self->echo('Extracting history section','debug');
         $self->_setHistory($pageData->{content},$node);
      } elsif ($node->getTagName eq 'introductory') {
         $self->echo('Extracting introductory section','debug');
         $self->_setIntroduction($pageData->{content},$node);
      }
   }
   $doc->dispose; #clean up the DOM, so that it's not left in memory.
   1;
}

################################################################################
# Private Method
# Extract the introduction from the Document and add it to the page content data
# $content - The content hash initialised at the start of "build"
# $IntroNode - The <introductory> element node
################################################################################
sub _setIntroduction {
   my $self = shift;
   my ($content, $IntroNode) = @_;
   
   my %introduction;
   #assumes only 1 <introduction> element will exist under <introductory>
   my $introRec = $IntroNode->getElementsByTagName('introduction',0)->[0];
   if (!$introRec) {
      $self->echo('No introduction record found in the introductory section..skipping','error');
      return;
   }
   
   #Add overview to introduction
   #Assumes only 1 <overview> element will exist under <introduction> &
   #extract the text
   my $overview = $introRec->getElementsByTagName('overview',0)->[0];
   if ($overview) {
      my $text = $self->_getElementText($overview);
      if ($text) {
         my @textLines = split(/\n/,$text);
         $introduction{overview} = \@textLines;
      }
   }

   #Add introduction to content
   if (keys %introduction) {
      $content->{introduction} = \%introduction;
   } else {
      $self->echo('No introduction found','debug');
   }
}

################################################################################
# Private Method
# Extract the history from the Document and add it to the page content data
# $content - The content hash initialised at the start of "build"
# $IntroNode - The top level <history> element node
################################################################################
sub _setHistory {
   my $self = shift;
   my ($content, $histNode) = @_;
   
   my %history;
   #Get the second level <history> node, assumes only 1 of these will exist under the
   #main <history> element.
   my $histRec = $histNode->getElementsByTagName('history',0)->[0];
   if (!$histRec) {
      $self->echo('No history record found in the history section..skipping','error');
      return;
   }
   
   #Get all the detail level <history> element nodes, and extract the text from
   # each one.
   my @detail;
   foreach my $detail (@{$histRec->getElementsByTagName('history',0)}) {
      my $text = $self->_getElementText($detail);
      push(@detail, $text) if ($text);
   }
   
   #Add the detail to history
   $history{detail} = \@detail if (@detail);
      
   #Add history overview
   my $overview = $histRec->getElementsByTagName('overview',0)->[0];
   if ($overview) {
      my $text = $self->_getElementText($overview);
      $history{overview} = $text if ($text);
   }
   
   #Add history to content
   if (keys %history) {
      $content->{history} = \%history;
   } else {
      $self->echo('No history found','debug');
   }
}

################################################################################
# Private Method
# Extract the title attributes from the destination element and add it to the
# page content data (title may contain utf8 characters)
################################################################################
sub _setTitles {
   my $self = shift;
   my ($pageData,$doc) = @_;
   my $docElem = $doc->getDocumentElement;

   $pageData->{title} = $docElem->getAttribute('title');
   $pageData->{title_ascii} = $docElem->getAttribute('title-ascii');
}

################################################################################
# Private Method
# Generic module for extracting and returning the text of an element.
################################################################################
sub _getElementText {
   my $self = shift;
   my ($elem) = @_;

   my $textNode = $elem->getFirstChild;
   if (!$textNode) {
      $self->echo('No Text Data found in '.$elem->getNodeName.'','error');
      return(undef);
   }
   if ($textNode->getNodeType != $textNode->TEXT_NODE) {
      $self->echo('Expected '.$elem->getNodeName.' to contain Text Data','error');
      return(undef);
   }
   return(_trim($textNode->getData));
}

################################################################################
# Private Method
# simple method to trim text. (perl doesn't have a trim function for strings)
################################################################################
sub _trim {
   my $text = shift;
   
   $text =~ s/^\s*//;
   $text =~ s/\s*$//;
   $text;
}

################################################################################
# Private Method
# Automatically set the destinations object, if it wasn't passed through in the
# constructor.
################################################################################
sub _set_destinations {
   my $self = shift;
   
   return(Destinations->new());
}


__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;
__END__

=head1 NAME

DestnContent - Build the content for a Destination html page.

=head1 SYNOPSIS

  use DestnContent;
  use Destinations;
  
  my $destObj = Destinations->new(file => 'destinations.xml');
  my $pgData = DestnContent->new(destinations => $destObj);
  
  or if Args.pm is used
  
  use DestnContent;
  use Args;
  
  Args->initialize();
  my $pgData = DestnContent->new();

=head1 DESCRIPTION

Builds up content by adding any content it finds, into a hash structure, which
can then be used to generate the output.

=head1 ATTRIBUTES

=head2 destinations

  Data Type:   Destinations object
  Required:    Yes

Destinations object

=head1 METHODS

=head2 build

Takes a Hash reference, and builds up content data for a destination, adding to the
hash as it goes.

  $pgData->build($pageData)

It's expected that $pageData will contain the following keys:

=over 4

=item *

node_id: The atlas id used for retrieving the destination record, and basing the html file names on

=item *

title: The destination name

=item *

navigation: Initialised as an array for the navigation links

=item *

content: A hash containing The main content or details of the destination

=back

=cut
