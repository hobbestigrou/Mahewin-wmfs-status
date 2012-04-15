#!/usr/bin/env perl

use strict;
use warnings;

use MahewinWmfsStatus;

my $wmfs_status = MahewinWmfsStatus->new;
$wmfs_status->run;
