#!/usr/bin/env perl

use FindBin;
use Path::Class;
use Test::Class::Moose::Load Path::Class::Dir->new($FindBin::Bin,'lib');

Test::Class::Moose->new(statistics => 1, test_classes => \@ARGV)->runtests;
