#include <ruby/ruby.h>

static VALUE
singleton_p(VALUE self, VALUE obj)
{
    if (SPECIAL_CONST_P(obj)) rb_raise(rb_eTypeError, "special const");
    VALUE klass = RBASIC_CLASS(obj);
    if (!FL_TEST(klass, FL_SINGLETON)) return Qnil;
    return klass;
}

void
Init_singleton_p(VALUE klass)
{
    rb_define_singleton_method(klass, "singleton?", singleton_p, 1);
}
