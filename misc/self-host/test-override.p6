use Yup;
use Yup::Test <&read &check &ensure-feature-flag>;

my class StrOutput {
    has $.result = "";

    method flush() {}
    method print($s) { $!result ~= $s.gist }
}

sub is-result($input, $expected, $desc) {
    my $compunit = read($input);
    my $runtime-program = slurp("self-host/runtime.007");
    my $output = StrOutput.new;
    my $runtime = Yup.runtime(:$output);
    check($compunit, $runtime);
    my $ast = Yup.parser(:$runtime).parse($runtime-program);
    $ast.block.static-lexpad.properties<ast> = $compunit;
    $runtime.run($ast);

    is $output.result, $expected, $desc;
}

sub outputs($program, $expected, $desc) {
    my $output = StrOutput.new;
    my $runtime = Yup.runtime(:$output);
    my $parser = Yup.parser(:$runtime);
    my $compunit = $parser.parse($program);
    my $runtime-program = slurp("self-host/runtime.007");
    my $ast = Yup.parser(:$runtime).parse($runtime-program);
    $ast.block.static-lexpad.properties<ast> = $compunit;
    $runtime.run($ast);

    is $output.result, $expected, $desc;
}

sub is-error($input, $expected-error, $desc = $expected-error.^name) is export {
    skip("not at all sure what to do with is-error in runtime.007");
    # like, how does the error propagate up from runtime.007 to Runtime.pm?
    # there's probably a very nice answer to that, but we're not yet at the
    # point where we can easily see that answer
}

sub throws-exception($input, $expected-error, $desc = $expected-error.^name) is export {
    skip("not at all sure what to do with throws-exception in runtime.007");
    # see comment about is-error above
}

sub parses-to($program, $expected, $desc = "MISSING TEST DESCRIPTION", Bool :$unexpanded) {
    skip("test is parser-only and we're testing runtime.007");
}

sub parse-error($program, $expected-error, $desc = $expected-error.^name) {
    skip("test is parser-only and we're testing runtime.007");
}
