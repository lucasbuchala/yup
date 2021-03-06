use Yup::Grammar;
use Yup::Actions;

class Yup::Parser {
    has $.runtime = die "Must supply a runtime";
    has @!opscopes = $!runtime.builtin-opscope;
    has @!checks;

    method opscope { @!opscopes[*-1] }
    method push-opscope { @!opscopes.push: @!opscopes[*-1].clone }
    method pop-opscope { @!opscopes.pop }

    method postpone(&check:()) { @!checks.push: &check }

    method parse($program, Bool :$*unexpanded) {
        my %*assigned;
        my @*declstack;
        my $*in_routine = False;
        my $*parser = self;
        my $*runtime = $!runtime;
        @!checks = ();
        Yup::Grammar.parse($program, :actions(Yup::Actions))
            or die "Could not parse program";   # XXX: make this into X::
        for @!checks -> &check {
            &check();
        }
        return $/.ast;
    }
}

# vim: ft=perl6
