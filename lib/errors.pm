package errors;
use strict;
use 5.008;
our $VERSION = '0.01';
# $YAML::UseCode = 1;
# use XXX;

package Error;
use overload (
    '""'       =>   'stringify',
    '0+'       =>   'value',
    'bool'     =>   sub { return 1; },
    'fallback' =>   1
);

sub stringify {
    my $self = shift;
    return $self->{value};
}

sub value {
    my $self = shift;
    return $self->{value};
}

package errors;
my @stack = [];

sub import {
    my ($class, $arg1) = @_;
    my ($package, $module) = caller(0);
    die "'use Errors' does not accept any arguments" if $arg1;
    {
        no strict 'refs';
        *{$package . "::raise"} = \&raise;
        *{$package . "::try"} = \&try;
        *{$package . "::except"} = \&except;
        *{$package . "::finally"} = \&finally;
        *{$package . "::Error"} = \&Error;
    }
}

sub Error {
    my $value = shift;
    return bless {
        value => $value,
    }, 'Error';
}

sub raise {
    my $error = shift;
    die $error;
}

sub try(&;@) {
    my $code = shift;
    my $error;
    eval { &$code };
    if ($@) {
        $error = ref($@) ? $@ : Error($@);
    }
    for my $clause (@_) {
        if ($error and defined ($clause->{except})) {
            my $code = $clause->{except};
            $_ = $error;
            eval &$code;
            if ($@) {
                $error = ref($@) ? $@ : Error($@);
            }
        }
        elsif (defined $clause->{finally}) {
            my $code = $clause->{finally};
            $_ = $error;
            eval &$code;
        }
    }
}

sub except(&;@) {
    my $code = shift;
    return { except => $code }, @_;
}

sub finally(&) {
    my $code = shift;
    return { finally => $code };
}

1;

=encoding utf8

=head1 NAME

errors - Error Handling for Perl

=head1 STATUS

This module is still being designed. Don't use it yet.

=head1 SYNOPSIS

    use errors;

    try {
        raise Error("Something is not cool")
            if $uncool;
    }
    except {
        warn $_;
    }
    finally {
        cleanup();
    };

=head1 DESCRIPTION

Yet another attempt to add clean, sane, flexible and usable error
handling to Perl.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2009. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
