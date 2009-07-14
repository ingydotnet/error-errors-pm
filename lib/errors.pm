# == ToDo
# + Move Error.pm code into module
# + 'with' clashes with Moose
# + Remove Simple
# + Support $_ as error topic
#
# - Add system error classes
# - Support autodie
# - Move most Error stuff into errors package
# - Replace ObjectifyCallback
# 
# == Tests
# + otherwise
# + except
# + -with_using
# + $_ is used
#
# - assert function works
# - $@ is always undef
# - nesting of try stuff
# - works with Moose
# - works with Error
# - with becomes using if with already exists

#------------------------------------------------------------------------------
package errors;
use strict;
use 5.008;
our $VERSION = '0.04';

# use XXX; $YAML::UseCode = 1;

sub import {
    my ($class, $directive) = @_;
    if (not $directive) {
        $class->export_commands(
            qw(try with except otherwise finally assert)
        );
    }
    elsif ($directive eq '-with_using') {
        $class->export_commands(
            qw(try using except otherwise finally assert)
        );
    }
    elsif ($directive eq '-class') {
        my ($class, %fields) = @_[2..$#_];
        my $isa = $fields{-isa} || 'Exception';
        no strict 'refs';
        @{$class . '::ISA'} = ($isa);
    }
    else {
        die "Invalid usage of errors module: 'use errors @_[1..$#_]'";
    }
}

sub export_commands {
    my ($class, @exports) = @_;
    local @errors::subs::EXPORT = @exports;
    local $Exporter::ExportLevel += 2;
    errors::subs->import();
}

#------------------------------------------------------------------------------
# Inspired by code from Jesse Glick and Peter Seibel

package errors::subs;

use Exporter ();
our @ISA = qw(Exporter);

sub objectify {
    my $msg = shift;
    return RuntimeError->new($msg);
}

sub run_clauses ($$$\@) {
    my($clauses,$err,$wantarray,$result) = @_;
    my $code = undef;

    $err = objectify($err) unless ref($err);

    CATCH: {

	# catch
	my $catch;
	if(defined($catch = $clauses->{'catch'})) {
	    my $i = 0;

	    CATCHLOOP:
	    for( ; $i < @$catch ; $i += 2) {
		my $pkg = $catch->[$i];
		unless(defined $pkg) {
		    #except
		    splice(@$catch,$i,2,$catch->[$i+1]->($err));
		    $i -= 2;
		    next CATCHLOOP;
		}
		elsif(Scalar::Util::blessed($err) && $err->isa($pkg)) {
		    $code = $catch->[$i+1];
		    while(1) {
			my $more = 0;
			local($Exception::THROWN, $@);
                        $_ = $@ = $err;
			my $ok = eval {
			    $@ = $err;
			    if($wantarray) {
				@{$result} = $code->($err,\$more);
			    }
			    elsif(defined($wantarray)) {
			        @{$result} = ();
				$result->[0] = $code->($err,\$more);
			    }
			    else {
				$code->($err,\$more);
			    }
			    1;
			};
			if( $ok ) {
			    next CATCHLOOP if $more;
			    undef $err;
			}
			else {
			    $err = $@ || $Exception::THROWN;
				$err = objectify($err)
					unless ref($err);
			}
			last CATCH;
		    };
		}
	    }
	}

	# otherwise
	my $owise;
	if(defined($owise = $clauses->{'otherwise'})) {
	    my $code = $clauses->{'otherwise'};
	    my $more = 0;
        local($Exception::THROWN, $@);
            $_ = $@ = $err;
	    my $ok = eval {
		$@ = $err;
		if($wantarray) {
		    @{$result} = $code->($err,\$more);
		}
		elsif(defined($wantarray)) {
		    @{$result} = ();
		    $result->[0] = $code->($err,\$more);
		}
		else {
		    $code->($err,\$more);
		}
		1;
	    };
	    if( $ok ) {
		undef $err;
	    }
	    else {
		$err = $@ || $Exception::THROWN;

		$err = objectify($err) 
			unless ref($err);
	    }
	}
    }
    undef $_;
    undef $@;
    return $err;
}

sub try (&;$) {
    my $try = shift;
    my $clauses = @_ ? shift : {};
    my $ok = 0;
    my $err = undef;
    my @result = ();

    my $wantarray = wantarray();

    do {
	local $Exception::THROWN = undef;
	local $@ = undef;

	$ok = eval {
	    if($wantarray) {
		@result = $try->();
	    }
	    elsif(defined $wantarray) {
		$result[0] = $try->();
	    }
	    else {
		$try->();
	    }
	    1;
	};

	$err = $@ || $Exception::THROWN
	    unless $ok;
    };

    $err = run_clauses($clauses,$err,wantarray,@result)
    unless($ok);

    $clauses->{'finally'}->()
	if(defined($clauses->{'finally'}));

    if (defined($err))
    {
        if (Scalar::Util::blessed($err) && $err->can('throw'))
        {
            throw $err;
        }
        else
        {
            die $err;
        }
    }

    wantarray ? @result : $result[0];
}

# Each clause adds a sub to the list of clauses. The finally clause is
# always the last, and the otherwise clause is always added just before
# the finally clause.
#
# All clauses, except the finally clause, add a sub which takes one argument
# this argument will be the error being thrown. The sub will return a code ref
# if that clause can handle that error, otherwise undef is returned.
#
# The otherwise clause adds a sub which unconditionally returns the users
# code reference, this is why it is forced to be last.
#
# The catch clause is defined in Exception.pm, as the syntax causes it to
# be called as a method

sub with (&;$) {
    @_
}

sub using (&;$) {
    @_
}

sub finally (&) {
    my $code = shift;
    my $clauses = { 'finally' => $code };
    $clauses;
}

# The except clause is a block which returns a hashref or a list of
# key-value pairs, where the keys are the classes and the values are subs.

sub except (&;$) {
    my $code = shift;
    my $clauses = shift || {};
    my $catch = $clauses->{'catch'} ||= [];
    
    my $sub = sub {
	my $ref;
	my(@array) = $code->($_[0]);
	if(@array == 1 && ref($array[0])) {
	    $ref = $array[0];
	    $ref = [ %$ref ]
		if(UNIVERSAL::isa($ref,'HASH'));
	}
	else {
	    $ref = \@array;
	}
	@$ref
    };

    unshift @{$catch}, undef, $sub;

    $clauses;
}

sub otherwise (&;$) {
    my $code = shift;
    my $clauses = shift || {};

    if(exists $clauses->{'otherwise'}) {
	require Carp;
	Carp::croak("Multiple otherwise clauses");
    }

    $clauses->{'otherwise'} = $code;

    $clauses;
}

sub assert($$) {
    my ($value, $msg) = @_;
    return $value if $value;
    throw AssertionError($msg);
    die($msg);
}

#------------------------------------------------------------------------------
package Exception;

use strict;

use overload (
	'""'	   =>	'stringify',
	'0+'	   =>	'value',
	'bool'     =>	sub { return 1; },
	'fallback' =>	1
);

$Exception::Depth = 0;	# Depth to pass to caller()
$Exception::Debug = 0;	# Generate verbose stack traces
$Exception::THROWN = undef;	# last error thrown, a workaround until die $ref works

my $LAST;		# Last error created
my %ERROR;		# Last error associated with package

# Exported subs are defined in errors::subs

use Scalar::Util ();

# I really want to use last for the name of this method, but it is a keyword
# which prevent the syntax  last Exception

sub prior {
    shift; # ignore

    return $LAST unless @_;

    my $pkg = shift;
    return exists $ERROR{$pkg} ? $ERROR{$pkg} : undef
	unless ref($pkg);

    my $obj = $pkg;
    my $err = undef;
    if($obj->isa('HASH')) {
	$err = $obj->{'__Error__'}
	    if exists $obj->{'__Error__'};
    }
    elsif($obj->isa('GLOB')) {
	$err = ${*$obj}{'__Error__'}
	    if exists ${*$obj}{'__Error__'};
    }

    $err;
}

sub flush {
    shift; #ignore
    
    unless (@_) {
       $LAST = undef;
       return;
    }
    
    my $pkg = shift;
    return unless ref($pkg);
   
    undef $ERROR{$pkg} if defined $ERROR{$pkg}; 
} 

# Return as much information as possible about where the error
# happened. The -stacktrace element only exists if $Exception::DEBUG
# was set when the error was created

sub stacktrace {
    my $self = shift;

    return $self->{'-stacktrace'}
	if exists $self->{'-stacktrace'};

    my $text = exists $self->{'-text'} ? $self->{'-text'} : "Died";

    $text .= sprintf(" at %s line %d.\n", $self->file, $self->line)
	unless($text =~ /\n$/s);

    $text;
}


sub associate {
    my $err = shift;
    my $obj = shift;

    return unless ref($obj);

    if($obj->isa('HASH')) {
	$obj->{'__Error__'} = $err;
    }
    elsif($obj->isa('GLOB')) {
	${*$obj}{'__Error__'} = $err;
    }
    $obj = ref($obj);
    $ERROR{ ref($obj) } = $err;

    return;
}


sub new {
    my $self = shift;
    my($pkg,$file,$line) = caller($Exception::Depth);

    my $err = bless {
	'-package' => $pkg,
	'-file'    => $file,
	'-line'    => $line,
        ((@_ % 2) ? ('-text') : ()),
	@_
    }, $self;

    $err->associate($err->{'-object'})
	if(exists $err->{'-object'});

    # To always create a stacktrace would be very inefficient, so
    # we only do it if $Exception::Debug is set

    if($Exception::Debug) {
	require Carp;
	local $Carp::CarpLevel = $Exception::Depth;
	my $text = defined($err->{'-text'}) ? $err->{'-text'} : "Exception";
	my $trace = Carp::longmess($text);
	# Remove try calls from the trace
	$trace =~ s/(\n\s+\S+__ANON__[^\n]+)?\n\s+eval[^\n]+\n\s+errors::subs::try[^\n]+(?=\n)//sog;
	$trace =~
        s/(\n\s+\S+__ANON__[^\n]+)?\n\s+eval[^\n]+\n\s+errors::subs::run_clauses[^\n]+\n\s+errors::subs::try[^\n]+(?=\n)//sog;
	$err->{'-stacktrace'} = $trace
    }

    $@ = $LAST = $ERROR{$pkg} = $err;
}

# Throw an error. this contains some very gory code.

sub throw {
    my $self = shift;
    local $Exception::Depth = $Exception::Depth + 1;

    # if we are not rethrow-ing then create the object to throw
    $self = $self->new(@_) unless ref($self);
    
    die $Exception::THROWN = $self;
}

# catch clause for
#
# try { ... } catch CLASS with { ... }

sub catch {
    my $pkg = shift;
    my $code = shift;
    my $clauses = shift || {};
    my $catch = $clauses->{'catch'} ||= [];

    unshift @$catch,  $pkg, $code;

    $clauses;
}

# Object query methods

sub object {
    my $self = shift;
    exists $self->{'-object'} ? $self->{'-object'} : undef;
}

sub file {
    my $self = shift;
    exists $self->{'-file'} ? $self->{'-file'} : undef;
}

sub line {
    my $self = shift;
    exists $self->{'-line'} ? $self->{'-line'} : undef;
}

sub text {
    my $self = shift;
    exists $self->{'-text'} ? $self->{'-text'} : undef;
}

# overload methods

sub stringify {
    my $self = shift;
    defined $self->{'-text'} ? $self->{'-text'} : "Died";
}

sub value {
    my $self = shift;
    exists $self->{'-value'} ? $self->{'-value'} : undef;
}

#------------------------------------------------------------------------------
package RuntimeError;
our @ISA = 'Exception';

package AssertionError;
our @ISA = 'Exception';

1;

=encoding utf8

=head1 NAME

errors - Error Handling for Perl

=head1 STATUS

This module is still under design. Don't use it in production yet. See
L<errors::Design> for more information.

A few things in this documentation are not yet implemented.

NOTE: If you have suggestions as to how this module should behave, now
      is a great time to contact the author.

=head1 SYNOPSIS

    use strict;
    use warnings;
    use errors;

    use errors -class => 'UncoolError';

    try {
        $cool = something();
        throw UncoolError("Something is not cool")
            if not $cool;
        assert($ok, "Everything is ok");
    }
    catch UncoolError with {
        my $e = shift;
        warn "$e";
    }
    catch UserError, RuntimeError with {
        # catch UserError or RuntimeError
        # $_ is the same as $_[0]
        warn;
    }
    except {
        # $@ is the same as $_[0]
        warn "Some other error: $@";
    }
    otherwise {
        warn "No error occurred in the try clause."
    }
    finally {
        cleanup();
    };

=head1 DESCRIPTION

The C<errors> module adds clean, simple, sane, flexible and usable error
handling to Perl. The module does several things:

First, C<errors> exports an error handling syntax that is very similar
to Error.pm, but with a few improvements. (See L<COMPARISON TO Error.pm>)

Second, all errors that are thrown are first class Perl objects. They
all inherit from the C<Exception> class, which is provided by default.
This allows you to manipulate errors in a consistent and intuitive way.

Third, The C<errors> module makes it trivial to define your own error
classes, and encourages you to do so. Simply define a class that
inherits from C<Exception> (or one of its subclasses).

Fourth, C<errors> turns plain (string based) system errors and other
die/croak errors into specific Perl objects. It uses heuristics on the error
string to determine which Error class to use, and defaults to the C<RuntimeError>
class.

Fifth, C<errors> provides dozens of predefined error classes that you
can use or that get used automatically by the auto-objectification.
These classes are in an inheritance hierarchy that should become
standard for Perl.

Lastly, C<errors> is designed to play nice with the modern Perl
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
    except FooError as e:
        handle_error(e)

Now you can do that in Perl:

    use errors;

    package FooError;
    use base 'Exception';
    package MyModule;

    try {
        something();
    }
    catch FooError with {
        my $e = shift;
        handle_error($e);
    };

As you can see, using C<errors> is simple and unobtrusive. Why not start
all your programs with:

    use strict;
    use errors;
    use warnings;

Defining your own error classes is also trivial, and C<errors> provides
an even more concise way to do it:

    use errors -class => 'FooError';

In the catch/with clause, you can also use C<$@> (or C<$_>) to access
the current error object like this:

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
The default base class is C<Exception>.

NOTE: This usage does not export the C<errors> (try/catch) syntax.

=item use errors -with_using;

Unfortunately C<Moose> and C<errors> both export the C<with> subroutine.
If C<errors> sees that C<Moose> (or someone else) has already exported
C<with>, it will export the C<using> subroutine instead:

    use Moose;
    use errors;
    try {...} catch Exception using {...};

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

=item except { ... }

This clause is invoked when there is an error from the C<try> block, but no
C<catch> clauses were invoked.

=item otherwise { ... }

This clause is invoked if there was no error in the C<try> clause.

=item finally { ... }

This clause is always invoked as the final step in the C<try> sequence,
regardless of what happens.

=item throw("...");

The throw keyword is not actually exported. It is a method call on the
Exception object. So you can use it indirectly or directly. These two
calls are identical:

    throw MyError("Something is wrong");
    MyError->throw("Something is wrong");

You can also use throw to reraise an error in a catch/except block,
like this:

    $@->throw();

=item assert($value, "assertion message");

This function will C<throw AssertionError($message) error unless
C<$value> is true.

=back

=head1 ERROR OBJECTS

All errors are Perl objects. They all have the 'Exception' class as
their topmost parent class. They all have the following methods and
properties:

=over

=item throw Exception($msg [, %properties]);

This method throws a new instance of the Exception class. It is
described more fully above.

=item $@->text()

The C<text> method gets or sets the error message for the object.

=item Stringification

All Exception objects turn into their C<text> string value when used in string
context.

=item Numification

All Exception objects turn into a unique number when used in numeric context.

=over

=head1 PREDEFINED CLASSES

The C<errors> module defines a number of error classes that it uses to cast
errors into. You can also create error objects yourself using these classes.
The classes are defined in a hierarchy:

    + Exception
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

Indicates an unknown error probably caused by a C<die> statement..

=back

NOTE: These error classes are still being determined. This list is not yet
complete. The current hierarchy was influenced from these sources.

    * http://search.cpan.org/perldoc?autodie#CATEGORIES
    * http://www.python.org/dev/peps/pep-0348/#new-hierarchy

=head1 COMPARISON TO Error.pm

The try/catch/throw interface of both Errors.pm and errors.pm is very
similar. You can use both in the same runtime process (but you can only
use one or the other in the same class/package).

The C<errors> module differs from the <Error> module in the following ways:

=over

=item catch Selector with { ... }

The Selector for the catch clause can only be a single class name in
Error.pm. In C<errors> it is much more flexible. See documentation
for details.

=item except { ... }

The except clause in Error.pm has weird semantics. In C<errors> it just
gets called if there is an error and no catch clause matches.

=item otherwise { ... }

The otherwise clause in Error.pm gets called if no other handler is
appropriate. In C<errors>, it behaves like an 'else' block. It is called
when there is no error at all in the try clause.

=item Base Class

Errors in the C<Error> module have a common base class of 'Error'. In
C<errors>, the base class is called 'Exception'.

=back

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
