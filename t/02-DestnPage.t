#!/usr/bin/perl

use English;
use warnings;
use File::Spec;
use FindBin;
use JSON;
use Path::Class;
use Test::Most 'no_plan';
use lib (Path::Class::Dir->new($FindBin::Bin,'..','lib')->resolve->stringify);
use Destinations;

BEGIN {
   use_ok('DestnPage');
}

{
    my $page = testNewDestinationPage();
    testPageGenerate($page);
}

#Test new DestnPage object
sub testNewDestinationPage {
   die_on_fail;
   my $page = new_ok('DestnPage' => [destinations => Destinations->new(file => Path::Class::File->new($FindBin::Bin,'Data','destntest.xml')),
      path => Path::Class::Dir->new($FindBin::Bin,'Data'),
      templateConfig => Path::Class::File->new($FindBin::Bin,'..','cfg','Template.cfg')->resolve],
      'New DestnPage object');
   
   can_ok($page, qw/destinations path templateConfig generate/);
   restore_fail;
   return($page);
}

sub testPageGenerate {
   my ($page) = @_;
   
   #clean up any html pages in the Data, as testing is to the html file is generated
   unlink(glob(File::Spec->catfile($FindBin::Bin,'Data','*.html')));
   
   #test html page generation
   my $destn = decodeData();
   lives_ok { $page->generate($destn) } 'Generating html page';
   
   ok(-e Path::Class::File->new($FindBin::Bin,'Data','355611.html'), 'html page generated');
}

sub decodeData {
   my $json = JSON->new();
   my @data = <DATA>;
   close(DATA);
   my $jsonStr = join('',@data);
   my $data = $json->decode($jsonStr);
   $data;
}

__DATA__;
{
   "atlas_node_id" : "355611",
   "ethyl_content_object_id" : "3210",
   "geo_id" : "355611",
   "node_name" : "South Africa",
   "navigation" : [
      {
         "href" : "355064.html",
         "name" : "Africa"
      }
   ],
   "children" : [
      {
         "atlas_node_id" : "355612",
         "ethyl_content_object_id" : "35474",
         "geo_id" : "355612",
         "node_name" : "Cape Town",
         "navigation" : [
            {
               "href" : "355064.html",
               "name" : "Africa"
            },
            {
               "href" : "355611.html",
               "name" : "South Africa"
            }
         ]
      },
      {
         "atlas_node_id" : "355614",
         "ethyl_content_object_id" : "",
         "geo_id" : "355614",
         "node_name" : "Free State",
         "navigation" : [
            {
               "href" : "355064.html",
               "name" : "Africa"
            },
            {
               "href" : "355611.html",
               "name" : "South Africa"
            }
         ]
      }
   ]
}
