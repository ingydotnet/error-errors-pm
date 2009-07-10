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
    my ($package, $module) = caller(0);
    die "'use Errors' does not accept any arguments" if $arg1;
    local $Exporter::ExportLevel = $Exporter::ExportLevel + 1;
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
        throw Error("Something is not cool")
            if $uncool;
    }
    catch Error with {
        my $e = shift;
        warn $e;
    }
    except {
        my $e = shift;
        print "Some other error: $e";
    }
    finally {
        cleanup();
    };

=head1 DESCRIPTION

The C<error> module adds clean, simple, sane, flexible and usable error
handling to Perl.

Currently it is almost an exact proxy for Error.pm. It gets rid of the
Error::Simple base class, and allows you to use 'Error' as the top
base class.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2009. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
