use inc::Module::Install;

name            'Error-errors';
all_from        'lib/errors.pm';

requires        'Error' => '0.17015';

WriteAll;
