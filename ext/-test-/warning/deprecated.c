#include <ruby/ruby.h>

static VALUE
deprecated_method(VALUE self)
{
    rb_category_warn("deprecated", "deprecated method");
    return self;
}

void
Init_deprecated(VALUE mod)
{
#define DEF(f) rb_define_module_function(mod, #f, f, 0)
    DEF(deprecated_method);
}
