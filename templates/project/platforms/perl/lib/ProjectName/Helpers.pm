package ProjectName::Helpers;
# Helper functions for {{REPO_NAME}}

use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(log_info log_error);

sub log_info {
    # Print an informational message to stdout.
    # Using prefix for visual consistency across scripts.
    my ($msg) = @_;
    print "[INFO] ${msg}\n";
}

sub log_error {
    # Print an error message to stderr.
    # Errors go to STDERR so they can be redirected independently.
    my ($msg) = @_;
    print STDERR "[ERROR] ${msg}\n";
}

1;
