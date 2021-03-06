#: override.t
#:
#: Description:
#:   The following test creates a makefile to ...
#: Details:

use t::Gmake;

plan tests => 3 * blocks();

run_tests;

__DATA__

=== TEST 0
--- source
override define foo
@echo First comes the definition.
@echo Then comes the override.
endef
all: 
	$(foo)
--- options:      foo=Hello
--- stdout
First comes the definition.
Then comes the override.
--- stderr
--- error_code: 0

