#include "ruby.h"

#define init(n) {void Init_##n(VALUE mod); Init_##n(mod);}

void
Init_warning(void)
{
    VALUE mBug = rb_define_module("Bug");
    VALUE mod = rb_define_module_under(mBug, "Warning");
    TEST_INIT_FUNCS(init);
}
