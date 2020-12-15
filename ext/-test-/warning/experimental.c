#include <ruby/ruby.h>

static VALUE
experimental_method(VALUE self)
{
    rb_category_warn("experimental", "experimental method");
    return self;
}

void
Init_experimental(VALUE mod)
{
#define DEF(f) rb_define_module_function(mod, #f, f, 0)
    DEF(experimental_method);
}
