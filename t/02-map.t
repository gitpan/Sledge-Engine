#!perl

use Test::More tests => 3;
use lib "./t/lib";

BEGIN {
    use_ok( 'MyApp' );
}
is scalar @{MyApp->components}, 2;
is_deeply({
    '/' => {
        class => 'MyApp::Pages::Root',
        method => 'index',
    },
    '/foo/bar' => {
        class => 'MyApp::Pages::Foo',
        method => 'bar',
    },
}, MyApp->ActionMap);


