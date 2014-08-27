################################################################################
# Author: Sten Hopkins
# See POD Documentation Below
################################################################################

package DestnPage;

use English;
use warnings;
use FindBin;
use Moose;
use MooseX::Privacy;
use Path::Class;
use Template;
use Try::Tiny;
use YAML;
use Args;

our $VERSION = '0.10';

with 'Role::PathClassable';
with 'Role::Notifiable';

################################################################################
# Attributes:
################################################################################
has 'path' => (isa => 'pathType',
   is => 'rw',
   required => 1,
   coerce => 1,
   lazy => 1,
   builder => '_setPathFromArgs',
   documentation => q/Full path of where the generated html Page is to be created/
);

has 'templateConfig' => (isa => 'fileType',
   is => 'rw',
   required => 1,
   coerce => 1,
   documentation => q/Configuration File (YAML) containing the template configurations/
);

has 'encoding' => (isa => 'Str',
   is => 'rw',
   default => '',
   documentation => q/Encoding type for the template output (eg utf-8)/
);

has '_tmplCfgs' => (isa => 'HashRef',
   is => 'rw',
   traits => ['Private'],
   lazy => 1,
   builder => '_setTmplCfgs',
   documentation => q/Reference to global configuration options for Template./
);

################################################################################
# Constructor:
################################################################################
sub BUILD {
   my $self = shift;

   $self->echo('New DestnPage object instantiated');
}

################################################################################
# Public Methods generate
# Takes page data ($pageData hash), and build the html content using Template to
# generate a destination page.
################################################################################
sub generate {
   my $self = shift;
   my ($pageData) = @_;

   my $destTmpl = Template->new($self->_tmplCfgs);

   #Store parameters for Template->process, in an array
   my @procParams = ('destinations.html',$pageData,
      Path::Class::File->new($self->path,$pageData->{node_id}.'.html')->stringify
   );
   
   #If the destinations file was encoded, use the same encoding for template output
   push(@procParams, {binmode => ':encoding('.$self->encoding.')'})
      if ($self->encoding);

   $self->echo('Generating file ['.$pageData->{node_id}.'.html]');
   $destTmpl->process(@procParams) || $self->exception($destTmpl->error);
   delete($pageData->{content}); #Clean up content as it's not longer needed
}

################################################################################
# Private Method _setTmplCfgs
# Initialise _tmplCfgs by reading in global template configurations from a YAML
# file.
################################################################################
sub _setTmplCfgs {
   my $self = shift;
   
   my $cfg;
   try {
      $cfg = YAML::LoadFile($self->templateConfig);
   } catch {
      $self->exception($_,'error');
   };
   # Convert Include paths (which should be relative to bin) to absolute.
   if (exists($cfg->{INCLUDE_PATH})) {
      my @incPath = map {Path::Class::Dir->new($FindBin::Bin,$_)->resolve->stringify}
         @{$cfg->{INCLUDE_PATH}};
      $cfg->{INCLUDE_PATH} = \@incPath;
   }
   return($cfg);
}

################################################################################
# Private Method _setPathFromArgs
# Will automatically set the path from the Args object, if it wasn't passed
# through in the construction.
################################################################################
sub _setPathFromArgs {
   my $self = shift;

   $self->echo('Path for generated html pages not passed through as an argument during
      instantiation. Attempting to automatically set it from the Command Line arguments');
   return(Args->instance()->path)
      if (Args->initialised);
}


__PACKAGE__->meta->make_immutable;
no Moose;

################################################################################
1;
__END__

=head1 NAME

DestnPage - Class for Generating a destination html page (basically a view).

=head1 SYNOPSIS

  use DestnPage;
  
  my $page = DestnPage->new(path => '/path/destinations',
     templateConfig => 'template.cfg');
  
  or if Args.pm is used
  
  use DestnPage;
  use Args;
  
  Args->initialize();
  my $page = DestnPage->new(templateConfig => 'template.cfg');
  ...
  $page->generate($pageDataHash);

=head1 DESCRIPTION

DestnPage takes a hash structure containing the content for a destination, and
produces a html page.

=head1 ATTRIBUTES

=head2 path

  Data Type:   Path::Class::Dir
  Required:    Yes

Full path of where the generated html Page is to be created. Will accept a string.

=head2 templateConfig

  Data Type:   Path::Class::File
  Required:    Yes

Configuration File (YAML) containing the template configurations

=head2 encoding

  Data Type:   Str
  Required:    Yes
  Default:     ''

Encoding type for the template output (eg utf-8)

=head1 METHODS

=head2 generate

Generates a Destination HTML Page in the directory specified by path, with details
provided in a Page Data Hash structure.

   $page->generate($pageDataHash);

As a minimum, $pageDataHash must contain the following keys:

=over 4

=item *

node_id: The node id is used as the basis for the html file names generated.

=item *

title: The destination name

=item *

navigation: An array (can be empty) for the navigation links

=item *

content: A hash (can be empty) containing the main content or details of the destination

=back

=cut
