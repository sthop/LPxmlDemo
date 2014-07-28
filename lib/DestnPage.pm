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
   documentation => q/Full path of where the generated Page is to be created/
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
   documentation => q/Store configuration option for Template./
);


################################################################################
# Public Methods generate
#
################################################################################
sub generate {
   my $self = shift;
   my ($pageData) = @_;
   
   $self->echo('Collecting Details for "'.
      $pageData->{node_name}.'" - atlas node id "'.$pageData->{atlas_node_id}.'"');
   
   $self->_buildContent($pageData);
   
   my $tmplCfg = $self->_tmplCfgs;
   my $destTmpl = Template->new($tmplCfg);

   $destTmpl->process('destinations.html',$pageData,
      Path::Class::File->new($self->path,$pageData->{atlas_node_id}.'.html')->stringify
   ) || $self->exception($destTmpl->error);
}

################################################################################
# Private Method _buildContent
#
################################################################################
sub _buildContent {
   my $self = shift;
   my ($pageData) = @_;
   
   $self->echo('Add Navigation for child destination nodes');
   $self->_setNavigation($pageData);
   my $doc = $self->destinations->getDestination($pageData->{atlas_node_id});
   $self->echo('Adding Title information to content');
   $self->_setTitles($pageData,$doc);
   $pageData->{content} = {};
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
# Private Method _setHistory
#
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
#
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
         
         @{$introduction{overview}} =
            map { (($_ =~ /\S/ && $self->_destEnc) ? 
               encode($self->_destEnc, $_) : $_)
            } @textLines;
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
#
################################################################################
sub _destEnc {
   my $self = shift;

   return($self->destinations->encoding);
}

################################################################################
# Private Method _setHistory
#
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
#
################################################################################
sub _setTitles {
   my $self = shift;
   my ($pageData,$doc) = @_;
   my $docElem = $doc->getDocumentElement;

   $pageData->{title} = $docElem->getAttribute('title');
   $pageData->{title_ascii} = $docElem->getAttribute('title-ascii');
}

################################################################################
# Private Method _childNavigation
#
################################################################################
sub _setNavigation {
   my $self = shift;
   my ($pageData) = @_;
   
   return if (!exists($pageData->{children}));
   while (my $child = shift(@{$pageData->{children}})) {
      push(@{$pageData->{navigation}},
         {href => $child->{atlas_node_id}.'.html', name => $child->{node_name}}
      );
   }
}

################################################################################
# Private Method _buildContent
#
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
# Private Method _getAncestors
#
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