use Test::More tests => 3;

use errors -with_using;

ok not(defined &with), "-with_using doesn't export with";
ok defined(&using), "-with_using exports using";

try {
    throw Error "Bad";
}
catch Error using {
    pass "catch with using";
    return;
}

