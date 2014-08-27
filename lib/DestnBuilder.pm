################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package DestnBuilder;

use English;
use warnings;
use Encode qw/encode/;
use Moose;
use MooseX::NonMoose;
use DestnContent;
extends 'XML::SAX::Base';

our $VERSION = '0.10';

with 'Role::Notifiable';

################################################################################
# Attributes:
################################################################################

has 'destnContent' => (isa => 'DestnContent',
   is => 'rw',
   required => 1,
   lazy => 1,
   builder => '_set_destnContent',
   documentation => q/Destination Content for building up the data content for the destination page/
);

has 'destnPage' => (isa => 'DestnPage',
   is => 'rw',
   required => 1,
   documentation => q/DestnPage Object for generating a html destination page/
);

has '_stack' => (isa => 'ArrayRef',
   is => 'rw',
   default => sub {[]},
   documentation => q/Internal stack representation, as the node tree structure is traversed/
);

has '_cur_elem' => (isa => 'Str',
   is => 'rw',
   default => '',
   documentation => q/Stores the current element name/
);

################################################################################
# Constructor:
################################################################################
sub BUILD {
   my $self = shift;

   $self->destnPage->encoding($self->destnContent->destinations->encoding);
   $self->echo('New DestnBuilder XML SAX Handler object instantiated');
}

################################################################################
# Public Method
# Called by the SAX parser when a start element is detected
################################################################################
sub start_element {
   my $self = shift;
   my ($data) = @_;
   
   #Track the current element name (used mainly when charcter/text data is found)
   my $cur_elem = $self->_cur_elem($data->{LocalName});
   #Only interested in 'node' and 'taxonomy' elements
   if ($cur_elem eq 'node' || $cur_elem eq 'taxonomy') {
      my $cur = _getAttribs($data);
      #push the details onto the stack as we find each new node
      push(@{$self->_stack},$cur);
   }
}

################################################################################
# Public Method
# Called by the SAX parser when an end element is detected
################################################################################
sub end_element {
   my $self = shift;
   my ($data) = @_;
   
   if ($data->{LocalName} eq 'node' || $data->{LocalName} eq 'taxonomy') {
      my $cur = $self->_stack->[$#{$self->_stack}];
      my $content = {};
      
      #Handle special case Taxonomy element. This is the "World" level
      if ($data->{LocalName} eq 'taxonomy') {
         $content->{title} = $cur->{taxonomy_name};
         $cur->{atlas_node_id} = 'index';
      }
      if ($self->destnContent->build($cur->{atlas_node_id},$content) || $data->{LocalName} eq 'taxonomy') {
         #Sort and add the current node's (built up) navigation details to the page content
         @{$content->{navigation}} = sort {$a->{label} cmp $b->{label}} @{$cur->{navigation}}
            if (exists($cur->{navigation}));
         
         #gather up the navigation details for ancestor destinations and prepend them to the
         #current navigation list.
         unshift(@{$content->{navigation}},$self->_ancestorNav());
         $self->destnPage->generate($content);
      } else {
         $self->warning('No content for node id ['.$cur->{atlas_node_id}.'] found. html page generation skipped...');
      }
      if ($#{$self->_stack} > 0) {
         my $parent = $self->_stack->[$#{$self->_stack} - 1]; #get the parent node
         #Build up the navigation details in the parent node
         push(@{$parent->{navigation}},
            {href => $content->{node_id}.'.html', label => $content->{title}});
         pop(@{$self->_stack}); #done with this node, pop it off the stack
      } else {
         $self->_stack([]); #Clean up the top level node (taxonomy element)
      }
   }
}

################################################################################
# Public Method
# Called by the SAX parser when element character/text data is found
################################################################################
sub characters {
   my $self = shift;
   my ($data) = @_;
  
  return if ($data->{Data} =~ /^\s*$/ || !$self->_cur_elem);
  my $cur = $self->_stack->[$#{$self->_stack}];
  my $elem = $self->_cur_elem; #Name of the current element
  #Add to the current node
  #$cur->{$elem} = '' if (!exists($cur->{$elem}));
  $cur->{$elem} .= $data->{Data};
}

################################################################################
# Private Method
# Returns a simple hash structure of the element's attributes
################################################################################
sub _getAttribs {
   my ($data) = @_;
   my $attribs = {};

   for (keys %{$data->{Attributes}}) {
      $attribs->{$data->{Attributes}{$_}{LocalName}} = $data->{Attributes}{$_}{Value};
   }
   return($attribs);
}

################################################################################
# Private Method
# Returns a list of navigation details for the current node's ancestors
################################################################################
sub _ancestorNav {
   my $self = shift;
   
   my $stack = $self->_stack; #for convenience
   return if (!$#{$stack}); #top level destination node won't have any navigation to a parent
   my $destns = $self->destnContent->destinations;
   my @ancestorNavs;
   for my $pos (0..$#{$stack} - 1) {
      my $titles;
      $titles = $destns->destinationTitles($stack->[$pos]{atlas_node_id})
         if (exists($stack->[$pos]{atlas_node_id}));
      my $navPoint = (exists($stack->[$pos]{taxonomy_name})) ?
         {href => 'index.html', label => $stack->[$pos]{taxonomy_name}} :
         {href => $stack->[$pos]{atlas_node_id}.'.html',
         label => $titles->{title}};
      push(@ancestorNavs, $navPoint);
   }
   return(@ancestorNavs);
}

################################################################################
# Private Method
# Automatically set the destnContent object, if it wasn't passed through in the
# constructor.
################################################################################
sub _set_destnContent {
   my $self = shift;
   
   $self->echo('Constructing a default DestnContent object');
   return(DestnContent->new());
}


__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;
__END__

=head1 NAME

DestnBuilder - The main controller module for generating Destination HTML pages.

=head1 SYNOPSIS

  use XML::SAX::ParserFactory;
  use Destinations;
  use DestnBuilder;
  use DestnContent;
  use DestnPage;
  
  my $dest = Destinations->new(...);
  my $content = DestnContent->new(destinations => $dest);
  my $page = DestnPage->new(...);
  
  my $builder = DestnBuilder->new(destnContent => $content, destnPage => $page);
  my $parsr = XML::SAX::ParserFactory->parser(Handler => $builder);
  my $parsr->parse_uri('taxonomy.xml');
  
  or if Args.pm is used
  
  use XML::SAX::ParserFactory;
  use DestnBuilder;
  use DestnPage;
  use Args;
  
  Args->initialize();
  my $page = DestnPage->new(...);
  my $builder = DestnBuilder->new(destnPage => $page);
  my $parsr = XML::SAX::ParserFactory->parser(Handler => $builder);
  my $parsr->parse_uri('taxonomy.xml');

=head1 DESCRIPTION

The DestnBuilder class is essentially a handler for a SAX parser. The methods in
this class are called by the parser, rather than called directly. To use it,
instantiate a SAX parser, passing the builder as the handler, then call one of
the parser methods.

The DestnBuilder traverses the taxonomy tree, extracting content and creating each
destination page as it goes along.

=head1 ATTRIBUTES

=head2 destnContent

  Data Type:   DestnContent object
  Required:    Yes

Destination Content for building up the data content for the destination page

=head2 destnPage

  Data Type:   destnPage object
  Required:    Yes

DestnPage Object for generating a html destination page

=cut
