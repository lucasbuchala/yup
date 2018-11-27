use v6;
use Test;

my @lines-with-made =
    qqx[grep -Fwrin '.made' lib/Yu/Parser/Actions.pm6].lines;  # XXX File may be non-existent

is @lines-with-made.join("\n"), "",
    "all .ast method calls are spelled '.ast' and not '.made'";

done-testing;
