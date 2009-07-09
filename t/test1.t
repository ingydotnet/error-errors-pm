use strict;
use Test::More tests => 5;

use errors;

try {
    pass "Pass try 1";
    raise Error("Error 1");
    fail "Fail try 1";
}
except {
    is ref, 'Error', '$_ contains proper object';
    is "$_", "Error 1", 'Stringify works';
    is $_->value, 'Error 1', 'value() method works';
}
finally {
    pass "Pass finally 1";
};
