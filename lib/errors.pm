# == ToDo
# - Support $_ as error topic
# - 'with' clashes with Moose
# - Add system error classes
# - Support autodie
# - Move Error.pm code into module
# 
# == Tests
# - nesting of try stuff
# - otherwise
# - except
# - assert
# - -with_using
package errors;
use strict;
use 5.008;
our $VERSION = '0.03';
use Error 0.17015;
use Error::Simple();

# use XXX; $YAML::UseCode = 1;

sub import {
    my ($class, $arg1) = @_;
    die "'use Errors' does not accept any arguments" if $arg1;
    local $Exporter::ExportLevel += 1;
    Error::subs->import(':try');
}

{
    no warnings 'redefine';
    # This function is modified from Error.pm
    sub Error::throw {
        my $self = shift;
        local $Error::Depth = $Error::Depth + 1;

        # if we are not rethrow-ing then create the object to throw
        unless (ref($self)) {
            my @args = @_;
            if ($self eq 'Error') {
                @args = (-text => $args[0], -value => $args[1]);
            }
            $self = $self->new(@args);
        }
        die $Error::THROWN = $self;
    }

    # Eliminate Error::Simple usage
    sub Error::Simple::new {
        die "Use 'Error' instead of 'Error::Simple'.";
    }
}

1;

=encoding utf8

=head1 NAME

errors - Error Handling for Perl

=head1 STATUS

This module is still under design. Don't use it in production yet.

=head1 SYNOPSIS

    use strict;
    use warnings;
    use errors;

    try {
        $cool = something();
        throw UncoolError("Something is not cool")
            if not $cool;
        assert($ok, "Everything is ok");
    }
    catch AssertionError with {
        my $e = shift;
        warn "$e";
    }
    catch UncoolError with {
        # $@ is the same as $_[0]
        warn "$@";
    }
    except {
        warn "Some other error: $@";
    }
    finally {
        cleanup();
    };

=head1 DESCRIPTION

The C<errors> module adds clean, simple, sane, flexible and usable error
handling to Perl. The module does several things:

First, C<errors> exports a error handling syntax that is backwards
compatible with Error.pm, but with a few improvements. Error.pm syntax
is very well done; about as close to other modern language's exception
handling as you can get using Pure Normal Perl.

Second, all errors that are thrown are first class Perl objects. They
all inherit from the C<Error> class, which is provided by default. This
allows you to manipulate errors in a consistent and intuitive way.

Third, The C<errors> module makes it trivial to define your own error
classes, and encourages you to do so. Simply define a class that
inherits from C<Error> (or one of its subclasses).

Fourth, C<errors> turns plain (string based) system errors and other
die/croak errors into specific Perl objects. It uses heuristics on the error
string to determine which Error class to use, and defaults to the C<RuntimeError>
class.

Fifth, C<errors> provides dozens of predefined error classes that you
can use or that get used automatically by the auto-objectification.
These classes are in an inheritance hierarchy that should become
standard for Perl.

Lastly, C<errors> is designed to play nice with all the modern Perl
frameworks (like Moose) and the other popular error handling modules.

=head1 SIMPLE TO USE

The main goal of C<errors> is to encourage the widespread use of error
handling in Perl. In other languages like Python, coining your own named
error classes and using raise/except is as common as using if/else
statements. Here's a Python example.

    class FooError(Exception):
        pass

    try:
        something()
    catch FooError as e:
        handle_error(e)

Now you can do that in Perl:

    use errors;

    package FooError;
    use base 'Error';
    package MyModule;

    try {
        something();
    }
    catch FooError with {
        my $e = shift;
        handle_error($e);
    };

As you can see, using C<errors> is simple and unobtrusive. Why not start all
your programs with:

    use strict;
    use errors;
    use warnings;

Defining your own error classes is also trivial, and C<errors> provides an
even more concise way to do it:

    use errors -class => 'FooError';

In the catch/with clause, you can also use C<$@> to access the current
error object like this:

    catch FooError with {
        handle_error($@);
    };

=head1 USAGE

There are a few different usages of C<errors> that you should be aware of:

=over

=item use errors;

This exports the C<errors> syntax, and loads all the C<errors> functionality. 

=item use errors -class => 'ClassName' [, -isa => 'BaseClass'];

The C<-class> directive gives you a way to define an error subclass at compile
time, in one simple line of code. You can optionally specify the base class.
The default base class is C<Error>.

NOTE: This usage does not export the C<errors> (try/catch) syntax.

=item use errors -with_using;

Unfortunately C<Moose> and C<errors> both export the C<with> subroutine.
If C<errors> sees that C<Moose> (or someone else) has already exported
C<with>, it will export the C<using> subroutine instead:

    use Moose;
    use errors;
    try {...} catch Error using {...};

The C<-with_using> directive tells C<errors> to do this regardless.

=back

=head1 SYNTAX

The C<errors> module introduces a number of keyword constructs that you can
use to create and manage error objects.

=over

=item try { ... }

Like an eval block. After the code is evaluated, the appropriate clauses
(catch, except, otherwise, finally) are called.

=item catch <error-selector> with { ... }

This clause is invoked when an error happens in the C<try> block, and
the class of the error object satisfies the ErrorSelector specified. You
may specify many C<catch> clauses, to deal with different error
situations.

The <error-selector> can be any of the following forms:

    # Class matches a specific error class
    catch ErrorClass with { ... }
    # Class matches a specific regexp
    catch qr/.../ with { ... }
    # A subroutine returns a true value
    catch sub { ... } with { ... }
    # One of a list of error selectors
    catch selector1, selector2, selector3 with { ... }
    # All of an array list of selectors
    catch [ selector1, selector2, selector3 ] with { ... }

NOTE: This is a major difference from Error.pm, which only allows a
      single class as a selector.

=item except { ... }

This clause is invoked when there is an error from the C<try> block, but no
C<catch> clauses were invoked.

=item otherwise { ... }

This clause is invoked when no error occurs in the C<try> block.

=item finally { ... }

This clause is always invoked as the final step in the C<try> sequence,
regardless of whatever things happen.

=item throw("...");

The throw keyword is not actually exported. It is a method call on the
Error object. So you can use it indirectly or directly. These two calls
are identical:

    throw MyError("Something is wrong");
    MyError->throw("Something is wrong");

You can also use throw to reraise an error in a catch/except block, like this:

    $@->throw();

=item assert($value, "assertion message");

This function will throw an AssertionError error unless C<$value> is true.

=back

=head1 ERROR OBJECTS

All errrors are Perl objects. They all have the 'Error' class as their
topmost parent class. They all have the following methods and
properties:

=over

=item throw Error($msg [, %properties]);

This method throws a new instance of the error class. It is described more
fully above.

=item $@->text()

The C<text> method gets or sets the error message for the object.

=item Stringification

All Error objects turn into their C<text> string value when used in string
context.

=item Numification

All Error objects turn into a unique number when used in numeric context.

=over

=head1 PREDEFINED CLASSES

The C<errors> module defines a number of error classes that it uses to cast
errors into. You can also create error objects yourself using these classes.
The classes are defined in a hierarchy:

    + Error
      + StandardError
        + ArithmeticError
          + DivideByZeroError
        + AssertionError
        + IOError
          + IOFileError
            + IOFileOpenError
        + NotImplementedError
        + SyntaxError
        + RuntimeError
      + UserError
        + user defined errors should inherit from this

Some of these are obvious. Some deserve elaboration.

=over

=item AssertionError

Indicates a failed C<assert> call.

=item SyntaxError

Indicates a bad string eval.

=item NotImplementedError

You can throw this in a stub subroutine.

=item RuntimeError

Indicates an unknown system error.

=back

NOTE: These error classes are still being determined. This list is not yet
complete. The current hierarchy was influenced from these sources.

    * http://search.cpan.org/perldoc?autodie#CATEGORIES
    * http://www.python.org/dev/peps/pep-0348/#new-hierarchy

=head1 FAQ

=over

=item Q: What is the difference between 'errors' and 'exceptions'?

=item A: Four letters.

=item Q: Is C<errors> performant?

=item A: Yes. Very. The module is small, simple, has no dependencies and
no string evals.

=item Q: Why another error/exception module?

=item A: Because it has the perfect name.

=back

=head1 ACKNOWLEDGEMENTS

The original code and ideas for this module were taken from Error.pm.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2009. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
