#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use ProjectName::Helpers qw(log_info log_error);

ok(defined &log_info,  'log_info is defined');
ok(defined &log_error, 'log_error is defined');
