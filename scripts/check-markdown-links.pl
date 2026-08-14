#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;

my $failed = 0;
for my $file (@ARGV) {
    open my $fh, '<', $file or die "Cannot read $file: $!\n";
    my $line_number = 0;
    while (my $line = <$fh>) {
        ++$line_number;
        while ($line =~ /(?<!!)\[[^\]]*\]\(([^ )]+)(?:\s+[^)]*)?\)/g) {
            my $target = $1;
            next if $target =~ m{^(?:https?://|mailto:|#)};
            $target =~ s/#.*\z//;
            next if $target eq '';
            my $path = File::Spec->rel2abs($target, dirname($file));
            next if -e $path;
            warn "$file:$line_number: broken relative link: $target\n";
            $failed = 1;
        }
    }
}
exit $failed;
