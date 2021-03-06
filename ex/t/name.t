use Test;
use Yup::Test;

my @lines = run-and-collect-lines("ex/name.yup");

is +@lines, 3, "correct number of lines of output";
is @lines[0], "info", "line #1 correct";
is @lines[1], "foo", "line #2 correct";
is @lines[2], "baz", "line #3 correct";

done-testing;
