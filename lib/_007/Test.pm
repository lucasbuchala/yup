use v6;
use _007;
use Test;

sub read(Str $ast) is export {
    my %qclass_lookup =
        int         => Q::Literal::Int,
        str         => Q::Literal::Str,
        ident       => Q::Term::Identifier,

        assign      => Q::Expr::Assignment,
        call        => Q::Expr::Call::Sub,

        vardecl     => Q::Statement::VarDecl,
        stexpr      => Q::Statement::Expr,

        compunit    => Q::CompUnit,
    ;

    my grammar _007::Syntax {
        regex TOP { \s* <expr> \s* }
        proto token expr {*}
        token expr:list { '(' ~ ')' [<expr>+ % \s+] }
        token expr:int { \d+ }
        token expr:symbol { \w+ }
        token expr:str { '"' ~ '"' (<-["]>+) }
    }

    my $actions = role {
        method TOP($/) { make $<expr>.ast }
        method expr:list ($/) {
            my $qname = ~$<expr>[0];
            die "Unknown name: $qname"
                unless %qclass_lookup{$qname} :exists;
            my $qclass = %qclass_lookup{$qname};
            my @rest = $<expr>».ast[1..*];
            make $qclass.new(|@rest);
        }
        method expr:symbol ($/) { make ~$/ }
        method expr:int ($/) { make +$/ }
        method expr:str ($/) { make ~$0 }
    };

    _007::Syntax.parse($ast, :$actions)
        or die "failure";
    return $/.ast;
}

role Output {
    has $.result = "";

    method say($s) { $!result ~= $s ~ "\n" }
}

sub is-result($input, $expected, $desc = "MISSING TEST DESCRIPTION") is export {
    my $ast = read($input);
    my $output = Output.new;
    my $runtime = _007.runtime(:$output);
    $runtime.run($ast, :$output);

    is $output.result, $expected, $desc;
}

