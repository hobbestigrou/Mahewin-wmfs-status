#!/usr/bin/env perl

use strict;
use warnings;

use App::MahewinWmfsStatus;

my $wmfs_status = App::MahewinWmfsStatus->new;
$wmfs_status->run;
