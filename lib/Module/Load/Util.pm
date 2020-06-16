package Module::Load::Util;

# AUTHORITY
# DATE
# DIST
# VERSION

use strict 'subs', 'vars';
use Regexp::Pattern::Perl::Module ();

use Exporter 'import';
our @EXPORT_OK = qw(
                       load_module_with_optional_args
                       instantiate_class_with_optional_args
               );

sub load_module_with_optional_args {
    my $opts = ref($_[0]) eq 'HASH' ? shift : {};
    my $module_with_optional_args = shift;

    my $target_package =
        defined $opts->{target_package} ? $opts->{target_package} :
        defined $opts->{caller} ? $opts->{caller} :
        caller(0);
    # check because we will use eval ""
    $target_package =~ $Regexp::Pattern::Perl::Module::RE{perl_modname}{pat}
        or die "Invalid syntax in target package '$target_package'";

    my ($module, $args) = @_;
    if (ref $module_with_optional_args eq 'ARRAY') {
        die "array form or module/class name must have 2 elements"
            unless @$module_with_optional_args == 2;
        $module = $module_with_optional_args->[0];
        $args = $module_with_optional_args->[1];
        $args = [%$args] if ref $args eq 'HASH';
        die "In array form of module/class name, the 2nd element must be ".
            "arrayref or hashref" unless ref $args eq 'ARRAY';
    } elsif (ref $module_with_optional_args) {
        die "module/class name must be string or 2-element array, not ".
            $module_with_optional_args;
    } elsif ($module_with_optional_args =~ /(.+?)=(.*)/) {
        $module = $1;
        $args = [split /,/, $2];
    } else {
        $module = $module_with_optional_args;
        $args = [];
    }

    if (defined $opts->{ns_prefix}) {
        $module =
            $opts->{ns_prefix} . ($opts->{ns_prefix} =~ /::\z/ ? '':'::') .
            $module;
    }

    # XXX option load=0?
    (my $modulepm = "$module.pm") =~ s!::!/!g;
    require $modulepm;

    my $do_import = defined $opts->{import} ? $opts->{import} : 1;
    if ($do_import) {
        eval "package $target_package; $module->import(\@{\$args});";
        die if $@;
    }

    {module=>$module, args=>$args};
}

sub instantiate_class_with_optional_args {
    my $opts = ref($_[0]) eq 'HASH' ? {%{shift()}} : {}; # shallow copy
    my $class_with_optional_args = shift;

    $opts->{import} = 0;
    $opts->{target_package} = caller(0);
    my $res = load_module_with_optional_args($opts, $class_with_optional_args);
    my $class = $res->{module};
    my $args  = $res->{args};

    my $do_construct = defined $opts->{construct} ? $opts->{construct} : 1;
    if ($do_construct) {
        my $constructor = defined $opts->{constructor} ?
            $opts->{constructor} : 'new';
        my $obj = $class->$constructor(@$args);
        return $obj;
    } else {
        return +{class=>$class, args=>$args};
    }
}

1;
# ABSTRACT: Some utility routines related to module loading

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 load_module_with_optional_args

Usage:

 load_module_with_optional_args( [ \%opts , ] $module_with_optional_args );

Examples:

 load_module_with_optional_args("Color::RGB::Util");                # default imports, equivalent to runtime version of 'use Color::RGB::Util'
 load_module_with_optional_args(["Color::RGB::Util", []]);          # ditto
 load_module_with_optional_args(["Color::RGB::Util", {}]);          # ditto

 load_module_with_optional_args("Color::RGB::Util=rgb2hsv");        # imports rgb2hsv. equivalent to runtime version of 'use Color::RGB::Util qw(rgb2hsv)'
 load_module_with_optional_args(["Color::RGB::Util", ["rgb2hsv"]]); # ditto
 load_module_with_optional_args(["Foo::Bar", {arg1=>1, arg2=>2}]);  # equivalent to runtime version of 'use Foo::Bar qw(arg1 1 arg2 2)'. hashref will be list-ified

 load_module_with_optional_args({import=>0}, "Color::RGB::Util");   # do not import,   equivalent to runtime version of 'use Color::RGB::Util ()'

 load_module_with_optional_args({ns_prefix=>"Color"}, "RGB::Util=rgb2hsv");        # equivalent to runtime version of 'use Color::RGB::Util qw(rgb2hsv)'
 load_module_with_optional_args({ns_prefix=>"Color"}, ["RGB::Util", ["rgb2hsv"]]); # ditto

Load a module with C<require()> followed by calling the module's C<import()>
(unless instructed to skip importing). Main feature of this function is the
flexibility in the C<$module_with_optional_args> argument, as well as some
options like namespace prefix. Suitable to be used to load plugins for your
application, for example, where you can specify the plugin to load as simply a
string or a 2-element array.

C<$module_with_optional_args> can be a string containing module name (e.g.
C<"Foo::Bar">), or a string containing module name string followed by C<=>,
followed by comma-separated list of imports, a la perl's C<-M> (e.g.
C<"Foo::Bar=arg1,arg2">), or a 2-element array where the first element is the
module name and the second element is an arrayref or hashref containing import
arguments (e.g. C<< ["Foo::Bar", ["arg1","arg2"]] >> or C<< ["Foo::Bar",
{arg1=>"val",arg2=>"val"]] >>). Hashref list of arguments will still be passed
as a list to C<import()>.

Will die on require() or import() failure.

Will return a hashref containing module name and arguments, e.g. C<<
{module=>"Foo", args=>["arg1",1,"arg2",2]} >>.

Known options:

=over

=item * import

Bool. Defaults to true. Can be set to false to avoid import()-ing.

=item * ns_prefix

Str. Namespace to use. For example, if you set this to C<WordList> then with
C<$module_with_optional_args> set to C<ID::KBBI>, the module
L<WordList::ID::KBBI> will be loaded.

=item * target_package

Str. Target package to import() to. Default is caller(0).

=back

=head2 instantiate_class_with_optional_args

Usage:

 instantiate_class_with_optional_args( [ \%opts , ] $class_with_optional_args );

Examples:

 my $obj = instantiate_class_with_optional_args("WordList::Color::Any");                           # equivalent to: require WordList::Color::Any; WordList::Color::Any->new;
 my $obj = instantiate_class_with_optional_args(["WordList::Color::Any"], []]);                    # ditto
 my $obj = instantiate_class_with_optional_args(["WordList::Color::Any"], {}]);                    # ditto

 my $obj = instantiate_class_with_optional_args("WordList::Color::Any=theme,Foo");                 # equivalent to: require WordList::Color::Any; WordList::Color::Any->new(theme=>"Foo");
 my $obj = instantiate_class_with_optional_args(["WordList::Color::Any",{theme=>"Foo"});           # ditto
 my $obj = instantiate_class_with_optional_args(["WordList::Color::Any",[theme=>"Foo"]);           # ditto
 my $obj = instantiate_class_with_optional_args(["Foo::Bar",[{arg1=>1, arg2=>2}]);                 # equivalent to: require Foo::Bar; Foo::Bar->new({arg1=>1, arg2=>2});

 my $obj = instantiate_class_with_optional_args({ns_prefix=>"WordList"}, "Color::Any=theme,Foo");  # equivalent to: require WordList::Color::Any; WordList::Color::Any->new(theme=>"Foo");

This is like L</load_module_with_optional_args> but the constructor arguments
specified after C<=> will be passed to the class constructor instead of used as
import arguments.

When you use the 2-element array form of C<$class_with_optional_args>, the
hashref and arrayref constructor arguments will be converted to a list.

Known options:

=over

=item * construct

Bool. Default to true. If set to false, constructor will not be called and the
function will just return the hashref containing class name and arguments, e.g.
C<< {class=>"Foo", args=>["arg1",1,"args2",2]} >>.

=item * constructor

Str. Select constructor name. Defaults to C<new>.

=item * ns_prefix

Str. Like in L</load_module_with_optional_args>.

=back


=head1 SEE ALSO

L<Module::Load>

L<Class::Load>

L<Sah::Schema::perl::modname_with_optional_args>
