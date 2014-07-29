################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package DestnPage;

use English;
use warnings;
use Encode qw/encode/;
use IO::File;
use Moose;
use Path::Class;
use Template;
use Try::Tiny;
use YAML;

with 'Role::PathClassable';
with 'Role::Notifiable';

################################################################################
# Attributes:
################################################################################

has 'destinations' => (isa => 'Destinations',
   is => 'rw',
   required => 1,
   documentation => q/Destinations object/
);

has 'path' => (isa => 'pathType',
   is => 'rw',
   required => 1,
   coerce => 1,
   documentation => q/Full path of where the generated html Page is to be created/
);

has 'templateConfig' => (isa => 'fileType',
   is => 'rw',
   required => 1,
   coerce => 1,
   documentation => q/Configuration File (YAML) containing the template configurations/
);

has '_tmplCfgs' => (isa => 'HashRef',
   is => 'rw',
   lazy => 1,
   builder => '_setTmplCfgs',
   documentation => q/Reference to global configuration options for Template./
);

################################################################################
# Public Methods generate
# Given page data, build up the content and uses Template to generate a
# destinations html page.
################################################################################
sub generate {
   my $self = shift;
   my ($pageData) = @_;
   
   $self->echo('Collecting Details for "'.
      $pageData->{node_name}.'" - atlas node id "'.$pageData->{atlas_node_id}.'"');
   
   #Build the html content data, adding it to $pageData
   $self->_buildContent($pageData);
   
   my $destTmpl = Template->new($self->_tmplCfgs);

   #Store parameters for Template->process, in an array
   my @procParams = ('destinations.html',$pageData,
      Path::Class::File->new($self->path,$pageData->{atlas_node_id}.'.html')->stringify
   );
   
   #If the destinations file was encoded, use the same encoding for template output
   push(@procParams, {binmode => ':encoding('.$self->destinations->encoding.')'})
      if ($self->destinations->encoding);

   $destTmpl->process(@procParams) || $self->exception($destTmpl->error);
   delete($pageData->{content}); #Clean up content as it's not longer needed
}

################################################################################
# Private Method _buildContent
# Main controlling method for building the detsinations page's content data.
################################################################################
sub _buildContent {
   my $self = shift;
   my ($pageData) = @_;
   
   $self->echo('Add Navigation for child destination nodes');

   #Set the navigation details for accessing child destination nodes (pages)
   #Any ancestor destination nodes should already be contained within $pageData
   $self->_setNavigation($pageData);
   
   #get the destination document
   my $doc = $self->destinations->getDestination($pageData->{atlas_node_id});
   $pageData->{content} = {};
   return if (!defined($doc));
   $self->echo('Adding Title information to content');
   
   #Add document data to the page contents
   $self->_setTitles($pageData,$doc);
   foreach my $node (@{$doc->getDocumentElement->getChildNodes}) {
      next if ($node->getNodeType != $node->ELEMENT_NODE);
      if ($node->getTagName eq 'history') {
         $self->echo('Extracting history section');
         $self->_setHistory($pageData->{content},$node);
      } elsif ($node->getTagName eq 'introductory') {
         $self->echo('Extracting introductory section');
         $self->_setIntroduction($pageData->{content},$node);
      }
   }
   $doc->dispose; #clean up the DOM, so that it's not left in memory.
}

################################################################################
# Private Method _getElementText
# Generic module for extracting and returning the text for an element.
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
# Private Method _setIntroduction
# Extract the introduction from the Document and add it to the page content data
################################################################################
sub _setIntroduction {
   my $self = shift;
   my ($content, $IntroNode) = @_;
   
   my %introduction;
   my $introRec = $IntroNode->getElementsByTagName('introduction',0)->[0];
   if (!$introRec) {
      $self->echo('No introduction record found in the introductory section..skipping','error');
      return;
   }
   
   #Add overview to introduction
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
      $self->echo('No introduction found');
   }
}

################################################################################
# Private Method _setHistory
# Extract the history from the Document and add it to the page content data
################################################################################
sub _setHistory {
   my $self = shift;
   my ($content, $histNode) = @_;
   
   my %history;
   my $histRec = $histNode->getElementsByTagName('history',0)->[0];
   if (!$histRec) {
      $self->echo('No history record found in the history section..skipping','error');
      return;
   }
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
      $self->echo('No history found');
   }
}

################################################################################
# Private Method _setTitles
# Extract the title information and add to the content data (title may contain utf8 characters)
################################################################################
sub _setTitles {
   my $self = shift;
   my ($pageData,$doc) = @_;
   my $docElem = $doc->getDocumentElement;

   $pageData->{title} = $docElem->getAttribute('title');
   $pageData->{title_ascii} = $docElem->getAttribute('title-ascii');
}

################################################################################
# Private Method _setNavigation
# Set the page navigation for child destination nodes. Assumes that if
# $pageData already contains the 'children' key, these will be for navigating to
# ancestor destination nodes.
################################################################################
sub _setNavigation {
   my $self = shift;
   my ($pageData) = @_;
   
   return if (!exists($pageData->{children}));
   #As the navigation details are built, child nodes are no longer required and
   #can be removed from the list of children.
   while (my $child = shift(@{$pageData->{children}})) {
      push(@{$pageData->{navigation}},
         {href => $child->{atlas_node_id}.'.html', name => $child->{node_name}}
      );
   }
}

################################################################################
# Private Method _setTmplCfgs
# Read in global template configurations from a YAML file, and return it as a
# hash reference. Used to initialise _tmplCfgs
################################################################################
sub _setTmplCfgs {
   my $self = shift;
   
   my $cfg;
   try {
      $cfg = YAML::LoadFile($self->templateConfig);
   } catch {
      $self->exception($_,'error');
   };
   return($cfg);
}

################################################################################
# Private Method _trim
# simple method to trim text. (perl doesn't have a trim function for strings)
################################################################################
sub _trim {
   my $text = shift;
   
   $text =~ s/^\s*//;
   $text =~ s/\s*$//;
   $text;
}

__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;
__END__

=head1 NAME

DestnPage - Generates a html page for Destination record.

=head1 SYNOPSIS

  use DestnPage;
  my $pg = DestnPage->new(destinations => $destObj,
     path => '/path/to/location/of/html/files',
     templateConfig => '/template/configs/yaml/file'
  );

=head1 DESCRIPTION

Builds up content data from a destinations record and generates a destination
html page.

=head1 ATTRIBUTES

=head2 destinations

  Data Type:   Destinations object
  Required:    Yes

Destinations object

=head2 path

  Data Type:   Path::Class::Dir
  Required:    Yes

Full path of where the generated html Page is to be created.

=head2 templateConfig

  Data Type:   Path::Class::File
  Required:    Yes

Configuration File (YAML) containing the template configurations

=head1 METHODS

=head2 generate

Takes a Hash reference, containing initial information, and builds up
content data for a destination, then generates the html page for that
destination.

  $pg->generate($pageData)

It's expected that $pageData will contain the following keys:

=over 4

=item *

atlas_node_id: The atlas id used for retrieving the destination record, and basing the html file names on

=item *

node_name: The destination name

=item *

navigation: contains any navigation (ancestor node/s if any) details (href, name)

=item *

children: Reference to child nodes (if any) containing similar information as $pageData itself.

=back

=cut