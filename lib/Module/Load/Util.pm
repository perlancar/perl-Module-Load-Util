package Module::Load::Util;

# AUTHORITY
# DATE
# DIST
# VERSION

use strict 'subs', 'vars';

use Exporter 'import';
our @EXPORT_OK = qw(load_module_with_optional_args);

sub load_module_with_optional_args {
    my $opts = ref($_[0]) eq 'HASH' ? shift : {};
    my $modname_with_optional_args = shift;

    my $caller = caller(0);

    if (defined $opts->{ns_prefix}) {
        $modname_with_optional_args =
            $ns_prefix . ($ns_prefix =~ /::\z/ ? '':'::') .
            $modname_with_optional_args;
    }

    my ($modname, $args) = @_;
    if ($modname_with_optional_args =~ /(.+?)=(.*)/) {
        $modname = $1;
        $args = [split /,/, $2];
    } else {
        $modname = $modname_with_optional_args;
        $args = [];
    }

    (my $modpm = "$modname.pm") =~ s!::!/!g;
    require $modpm;

    eval "package $caller; $mod->import(\@{\$args});";
    die if $@;
}

1;
# ABSTRACT:

=head1 SYNOPSIS


=head1 DESCRIPTION
