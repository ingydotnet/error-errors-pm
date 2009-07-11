use Test::More tests => 1;

use errors;

ok assert(1, '1 is ok'), 'assert is exported and works on true';

# try {
#     throw Error(42);
#     assert(0, '0 is not ok'), 'assert is exported and works on true';
# }
# except {
#     print ">> $@";
# };
