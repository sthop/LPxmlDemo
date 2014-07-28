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

has 'destnPage' => (isa => 'DestnPage',
   is => 'rw',
   required => 1,
   documentation => q/DestinationPage Object for generating a html destination page/
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
      $self->_ancestorNav($cur); #gather up the navigation details for ancestor destinations
      if ($#{$self->_stack} > 0) {
         $cur = $self->_stack->[$#{$self->_stack} - 1];
         push(@{$cur->{children}},$self->_stack->[$#{$self->_stack}]);
         pop(@{$self->_stack});
      } else {
         $self->_trav({});
      }
   }
   print '';
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
   my ($cur) = @_;
   
   my $stack = $self->_stack; #for convenience
   return if (!$#{$stack}); #top level destination node won't have any navigation to a parent
   my $destns = $self->destnPage->destinations;
   my $enc = $destns->encoding;
   for my $pos (0..$#{$stack} - 1) {
      my $titles;
      $titles = $destns->destinationTitles($stack->[$pos]{atlas_node_id})
         if (exists($stack->[$pos]{atlas_node_id}));
      my $navPoint = (exists($stack->[$pos]{taxonomy_name})) ?
         {href => 'index.html', name => 'World'} :
         {href => $stack->[$pos]{atlas_node_id}.'.html',
         name => ($enc ? encode($enc,$titles->{title}) : $titles->{title})};
      push(@{$cur->{navigation}}, $navPoint);
   }
}

__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;
__END__
