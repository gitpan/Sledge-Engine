package Sledge::Engine;

use strict;
use base qw(Class::Data::Inheritable);
use Scalar::Util qw(blessed);
use Class::Inspector;
use UNIVERSAL::require;
use Module::Pluggable::Object;
use Carp ();

use Sledge::Utils;

our $VERSION = '0.01';

__PACKAGE__->mk_classdata('ActionMap' => {});
__PACKAGE__->mk_classdata('ActionMapKeys' => []);
__PACKAGE__->mk_classdata('components' => []);

sub import {
    my $pkg = shift;
    my $caller = caller(0);
    no strict 'refs';
    my $engine = 'Sledge::Engine::CGI';
    if ($ENV{MOD_PERL}) {
        my($software, $version) = 
            $ENV{MOD_PERL} =~ /^(\S+)\/(\d+(?:[\.\_]\d+)+)/;
        if ($version >= 1.24 && $version < 1.90) {
            $engine = 'Sledge::Engine::Apache::MP13';
            *handler = sub ($$) { shift->run(@_); };
        } 
        else {
            Carp::croak("Unsupported mod_perl version: $ENV{MOD_PERL}");
        }
    }
    $engine->require;
    push @{"$caller\::ISA"}, $engine;
}

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self;
}

sub setup {
    my $pkg = shift;
    my $pages_class = join '::', $pkg, 'Pages';
    $pages_class->require or die $@;
    my $finder = Module::Pluggable::Object->new(
        search_path => [$pages_class],
        require => 1,
    );
    $pkg->components([$finder->plugins]);
    for my $subclass(@{$pkg->components}) {
        my $methods = Class::Inspector->methods($subclass, 'public');
        for my $method(@{$methods}) {
            if ($method =~ /^dispatch_/) {
                $pkg->register($subclass, $method);
            }
        }
    }
    $pkg->ActionMapKeys([
        sort { length($a) <=> length($b) } keys %{$pkg->ActionMap}
    ]);
}

sub register {
    my($pkg, $class, $method) = @_;
    my $prefix = Sledge::Utils::class2prefix($class);
    $method =~ s/^dispatch_//;
    my $path = $prefix eq '/' ? "/$method" : "$prefix/$method";
    $path =~ s{/index$}{/};
    $pkg->ActionMap->{$path} = {
        class => $class,
        method => $method,
    };
}

sub lookup {
    my($self, $path) = @_;
    $path ||= '/';
    $path =~ s{/index$}{/};
    if (my $action = $self->ActionMap->{$path}) {
        return $action;
    }
    # XXX handle arguments.
#     my $match;
#     for my $key(@{$self->ActionMapKeys}) {
#         next unless index($path, $key) >= 0;
#         if ($path =~ m{^$key}) {
#             $match = $key;
#         }
#     }
#     return unless $match;
#     my %action = %{$self->ActionMap->{$match}};
#     if (length($path) > length($match)) {
#         my $args = $path;
#         $args =~ s{^$match/?}{};
#         $action{args} = [split '/', $args];
#     }
#     return \%action;
}

sub run {
    my $self = shift;
    unless (blessed $self) {
        $self = $self->new;
    }
    $self->handle_request(@_);
}

sub handle_request {
    die "ABSTRACT METHOD!";
}

1;

__END__

=head1 NAME

Sledge::Engine - run Sledge based application (EXPERIMENTAL).

=head1 SYNOPSIS

 # MyApp.pm
 package MyApp;
 use Sledge::Engine;

 __PACKAGE__->setup;

 # mod_perl configuration.
 <Location />
     SetHandler perl-script
     PerlHandler MyApp 
 </Location>

 # CGI mode.
 #!/usr/bin/perl
 use strict;
 use MyApp;
 MyApp->run;


=head1 AUTHOR

Tomohiro IKEBE, C<< <ikebe@shebang.jp> >>

=head1 LICENSE

Copyright 2006 Tomohiro IKEBE, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

