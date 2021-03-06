use Yup::Val;
use Yup::Q;
use Yup::OpScope;
use Yup::Equal;

class X::Control::Exit is Exception {
    has Int $.exit-code;
}

sub wrap($_) {
    when Yup::Value | Q { $_ }
    when Nil  { NIL }
    when Bool { Yup::Type::Bool.new(:value($_)) }
    when Int  { Yup::Type::Int.new(:value($_)) }
    when Str  { Yup::Type::Str.new(:value($_)) }
    when Array | Seq | List { Yup::Type::Array.new(:elements(.map(&wrap))) }
    default { die "Got some unknown value of type ", .^name }
}

subset ValOrQ of Any where Yup::Value | Q;

sub assert-type(:$value, ValOrQ:U :$type, Str :$operation) {
    die X::TypeCheck.new(:$operation, :got($value), :expected($type))
        unless $value ~~ $type;
}

sub assert-nonzero(:$value, :$operation, :$numerator) {
    die X::Numeric::DivideByZero.new(:using($operation), :$numerator)
        if $value == 0;
}

multi less-value($l, $) {
    assert-type(:value($l), :type(Yup::Type::Int), :operation<less>);
}
multi less-value(Yup::Type::Int $l, Yup::Type::Int $r) { $l.value < $r.value }
multi less-value(Yup::Type::Str $l, Yup::Type::Str $r) { $l.value lt $r.value }
multi more-value($l, $) {
    assert-type(:value($l), :type(Yup::Type::Int), :operation<more>);
}
multi more-value(Yup::Type::Int $l, Yup::Type::Int $r) { $l.value > $r.value }
multi more-value(Yup::Type::Str $l, Yup::Type::Str $r) { $l.value gt $r.value }

my role Placeholder {
    has $.qtype;
    has $.assoc;
    has %.precedence;
}
my class Placeholder::MacroOp does Placeholder {
}
sub macro-op(:$qtype, :$assoc?, :%precedence?) {
    Placeholder::MacroOp.new(:$qtype, :$assoc, :%precedence);
}

my class Placeholder::Op does Placeholder {
    has &.fn;
}
sub op(&fn, :$qtype, :$assoc?, :%precedence?) {
    Placeholder::Op.new(:&fn, :$qtype, :$assoc, :%precedence);
}

my @builtins =
    p => -> *$args {},
    say => -> *$args {
        # implementation in Runtime.pm
    },
    prompt => sub ($arg) {
        # implementation in Runtime.pm
    },
    type => -> $arg { Yup::Type::Type.of($arg.WHAT) },
    exit => -> $int = Yup::Type::Int.new(:value(0)) {
        assert-type(:value($int), :type(Yup::Type::Int), :operation<exit>);
        my $exit-code = $int.value % 256;
        die X::Control::Exit.new(:$exit-code);
    },

    # OPERATORS (from loosest to tightest within each category)

    # assignment precedence
    'infix:=' => macro-op(
        :qtype(Q::Infix::Assignment),
        :assoc<right>,
    ),

    # disjunctive precedence
    'infix:||' => macro-op(
        :qtype(Q::Infix::Or),
    ),
    'infix://' => macro-op(
        :qtype(Q::Infix::DefinedOr),
        :precedence{ equiv => "infix:||" },
    ),

    # conjunctive precedence
    'infix:&&' => macro-op(
        :qtype(Q::Infix::And),
    ),

    # comparison precedence
    'infix:==' => op(
        sub ($lhs, $rhs) {
            my %*equality-seen;
            return wrap(equal-value($lhs, $rhs));
        },
        :qtype(Q::Infix),
        :assoc<non>,
    ),
    'infix:!=' => op(
        sub ($lhs, $rhs) {
            my %*equality-seen;
            return wrap(!equal-value($lhs, $rhs))
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:==" },
    ),
    'infix:<' => op(
        sub ($lhs, $rhs) {
            return wrap(less-value($lhs, $rhs))
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:==" },
    ),
    'infix:<=' => op(
        sub ($lhs, $rhs) {
            my %*equality-seen;
            return wrap(less-value($lhs, $rhs) || equal-value($lhs, $rhs))
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:==" },
    ),
    'infix:>' => op(
        sub ($lhs, $rhs) {
            return wrap(more-value($lhs, $rhs) )
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:==" },
    ),
    'infix:>=' => op(
        sub ($lhs, $rhs) {
            my %*equality-seen;
            return wrap(more-value($lhs, $rhs) || equal-value($lhs, $rhs))
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:==" },
    ),
    'infix:~~' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($rhs), :type(Yup::Type::Type), :operation<~~>);

            return wrap($lhs ~~ $rhs.type);
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:==" },
    ),
    'infix:!~~' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($rhs), :type(Yup::Type::Type), :operation<!~~>);

            return wrap($lhs !~~ $rhs.type);
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:==" },
    ),

    # additive precedence
    'infix:+' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($lhs), :type(Yup::Type::Int), :operation<+>);
            assert-type(:value($rhs), :type(Yup::Type::Int), :operation<+>);

            return wrap($lhs.value + $rhs.value);
        },
        :qtype(Q::Infix),
    ),
    'infix:~' => op(
        sub ($lhs, $rhs) {
            return wrap($lhs.Str ~ $rhs.Str);
        },
        :qtype(Q::Infix),
        :precedence{ equiv => "infix:+" },
    ),
    'infix:-' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($lhs), :type(Yup::Type::Int), :operation<->);
            assert-type(:value($rhs), :type(Yup::Type::Int), :operation<->);

            return wrap($lhs.value - $rhs.value);
        },
        :qtype(Q::Infix),
    ),

    # multiplicative precedence
    'infix:*' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($lhs), :type(Yup::Type::Int), :operation<*>);
            assert-type(:value($rhs), :type(Yup::Type::Int), :operation<*>);

            return wrap($lhs.value * $rhs.value);
        },
        :qtype(Q::Infix),
    ),
    'infix:%' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($lhs), :type(Yup::Type::Int), :operation<%>);
            assert-type(:value($rhs), :type(Yup::Type::Int), :operation<%>);
            assert-nonzero(:value($rhs.value), :operation("infix:<%>"), :numerator($lhs.value));

            return wrap($lhs.value % $rhs.value);
        },
        :qtype(Q::Infix),
    ),
    'infix:%%' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($lhs), :type(Yup::Type::Int), :operation<%%>);
            assert-type(:value($rhs), :type(Yup::Type::Int), :operation<%%>);
            assert-nonzero(:value($rhs.value), :operation("infix:<%%>"), :numerator($lhs.value));

            return wrap($lhs.value %% $rhs.value);
        },
        :qtype(Q::Infix),
    ),
    'infix:divmod' => op(
        sub ($lhs, $rhs) {
            assert-type(:value($lhs), :type(Yup::Type::Int), :operation<divmod>);
            assert-type(:value($rhs), :type(Yup::Type::Int), :operation<divmod>);
            assert-nonzero(:value($rhs.value), :operation("infix:<divmod>"), :numerator($lhs.value));

            return Yup::Type::Tuple.new(:elements([
                wrap($lhs.value div $rhs.value),
                wrap($lhs.value % $rhs.value),
            ]));
        },
        :qtype(Q::Infix),
    ),

    # prefixes
    'prefix:~' => op(
        sub prefix-str($expr) {
            Yup::Type::Str.new(:value($expr.Str));
        },
        :qtype(Q::Prefix),
    ),
    'prefix:+' => op(
        sub prefix-plus($_) {
            when Yup::Type::Str {
                return wrap(.value.Int)
                    if .value ~~ /^ '-'? \d+ $/;
                proceed;
            }
            when Yup::Type::Int {
                return $_;
            }
            assert-type(:value($_), :type(Yup::Type::Int), :operation("prefix:<+>"));
        },
        :qtype(Q::Prefix),
    ),
    'prefix:-' => op(
        sub prefix-minus($_) {
            when Yup::Type::Str {
                return wrap(-.value.Int)
                    if .value ~~ /^ '-'? \d+ $/;
                proceed;
            }
            when Yup::Type::Int {
                return wrap(-.value);
            }
            assert-type(:value($_), :type(Yup::Type::Int), :operation("prefix:<->"));
        },
        :qtype(Q::Prefix),
    ),
    'prefix:?' => op(
        sub ($a) {
            return wrap(?$a.truthy)
        },
        :qtype(Q::Prefix),
    ),
    'prefix:!' => op(
        sub ($a) {
            return wrap(!$a.truthy)
        },
        :qtype(Q::Prefix),
    ),
    'prefix:^' => op(
        sub ($n) {
            assert-type(:value($n), :type(Yup::Type::Int), :operation("prefix:<^>"));

            return wrap([^$n.value]);
        },
        :qtype(Q::Prefix),
    ),

    # postfixes
    'postfix:[]' => macro-op(
        :qtype(Q::Postfix::Index),
    ),
    'postfix:()' => macro-op(
        :qtype(Q::Postfix::Call),
    ),
    'postfix:.' => macro-op(
        :qtype(Q::Postfix::Property),
    ),
;

for Yup::Type::.keys.map({ "Yup::Type::" ~ $_ }) -> $name {
    my $type = ::($name);
    push @builtins, ($type.^name.subst("Yup::Type::", "") => Yup::Type::Type.of($type));
}
push @builtins, "Q" => Yup::Type::Type.of(Q);

my $opscope = Yup::OpScope.new();

sub install-op($name, $placeholder) {
    $name ~~ /^ (prefix | infix | postfix) ':' (.+) $/
        or die "This shouldn't be an op";
    my $type = ~$0;
    my $opname = ~$1;
    my $qtype = $placeholder.qtype;
    my $assoc = $placeholder.assoc;
    my %precedence = $placeholder.precedence;
    $opscope.install($type, $opname, $qtype, :$assoc, :%precedence);
}

my &ditch-sigil = { $^str.substr(1) };
my &parameter = { Q::Parameter.new(:identifier(Q::Identifier.new(:name(Yup::Type::Str.new(:$^value))))) };

@builtins.=map({
    when .value ~~ Yup::Type::Type {
        .key => .value;
    }
    when .value ~~ Block {
        my @elements = .value.signature.params».name».&ditch-sigil».&parameter;
        if .key eq "say"|'p' {
            @elements = parameter("...args");
        }
        my $parameterlist = Q::ParameterList.new(:parameters(Yup::Type::Array.new(:@elements)));
        my $statementlist = Q::StatementList.new();
        .key => Yup::Type::Sub.new-builtin(.value, .key, $parameterlist, $statementlist);
    }
    when .value ~~ Placeholder::MacroOp {
        my $name = .key;
        install-op($name, .value);
        my @elements = .value.qtype.attributes».name».substr(2).grep({ $_ ne "identifier" })».&parameter;
        my $parameterlist = Q::ParameterList.new(:parameters(Yup::Type::Array.new(:@elements)));
        my $statementlist = Q::StatementList.new();
        .key => Yup::Type::Sub.new-builtin(sub () {}, $name, $parameterlist, $statementlist);
    }
    when .value ~~ Placeholder::Op {
        my $name = .key;
        install-op($name, .value);
        my &fn = .value.fn;
        my @elements = &fn.signature.params».name».&ditch-sigil».&parameter;
        my $parameterlist = Q::ParameterList.new(:parameters(Yup::Type::Array.new(:@elements)));
        my $statementlist = Q::StatementList.new();
        .key => Yup::Type::Sub.new-builtin(&fn, $name, $parameterlist, $statementlist);
    }
    default { die "Unknown type {.value.^name}" }
});

my $builtins-pad = Yup::Type::Object.new;
for @builtins -> Pair (:key($name), :$value) {
    $builtins-pad.properties{$name} = $value;
}

sub builtins-pad() is export {
    return $builtins-pad;
}

sub opscope() is export {
    return $opscope;
}

# vim: ft=perl6
