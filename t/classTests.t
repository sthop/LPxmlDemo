#!/usr/bin/env perl

use Test::Class::Moose::Load 'lib';

Test::Class::Moose->new(statistics => 1, test_classes => \@ARGV)->runtests;
