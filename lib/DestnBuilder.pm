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
extends 'XML::SAX::Base';

################################################################################
# Attributes:
################################################################################

has 'destnContent' => (isa => 'DestnContent',
   is => 'rw',
   required => 1,
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
   documentation => q//
);

has '_cur_elem' => (isa => 'Str',
   is => 'rw',
   default => '',
   documentation => q//
);

################################################################################
# Constructor:
################################################################################
sub BUILD {
   my $self = shift;

   $self->destnPage->encoding($self->destnContent->destinations->encoding);
}

################################################################################
# Public Method
################################################################################
sub start_element {
   my $self = shift;
   my ($data) = @_;
   
   my $cur_elem = $self->_cur_elem($data->{LocalName});
   if ($cur_elem eq 'node' || $cur_elem eq 'taxonomy') {
      my $cur = _getAttribs($data);
      push(@{$self->_stack},$cur);
   }
}

################################################################################
# Public Method
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
      if ($self->destnContent->build($cur->{atlas_node_id},$content)) {
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
         my $parent = $self->_stack->[$#{$self->_stack} - 1];
         push(@{$parent->{navigation}},
            {href => $content->{node_id}.'.html', label => $content->{title}});
         pop(@{$self->_stack});
      } else {
         $self->_stack([]);
      }
   }
}

################################################################################
# Public Method
################################################################################
sub characters {
   my $self = shift;
   my ($data) = @_;
  
  return if ($data->{Data} =~ /^\s*$/ || !$self->_cur_elem);
  my $cur = $self->_stack->[$#{$self->_stack}];
  my $elem = $self->_cur_elem;
  $cur->{$elem} = '' if (!exists($cur->{$elem}));
  $cur->{$elem} .= $data->{Data};
}

################################################################################
# Private Method 
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
         {href => 'index.html', label => 'World'} :
         {href => $stack->[$pos]{atlas_node_id}.'.html',
         label => $titles->{title}};
      push(@ancestorNavs, $navPoint);
   }
   return(@ancestorNavs);
}

__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;
__END__
