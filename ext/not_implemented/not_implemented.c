#include <ruby.h>

/*
 *  call-seq:
 *    module.not_implemented(name, ...)    -> module
 *
 *  Define not-implemented methods.
 *
 *  The defined methods will raise NotImplementedError when called.
 *  and Object#respond_to? and Module#method_defined? will +false+ on
 *  these methods.
 *
 *    require 'not_implemented'
 *
 *    class Area
 *      not_implemented :calculate
 *    end
 *
 *    p Area.new.respond_to?(:calculate)
 *    p Area.method_defined?(:calculate)
 *    Area.new.calculate
 *
 *  <em>raises the exception:</em>
 *
 *    false
 *    false
 *    NotImplementedError: calculate() function is unimplemented on this machine
 *
 *  Keep in mind: NotImplementedError is not a descendant of StandardError and will
 *  not be rescued by a rescue clause without an explicit Exception class.
 */

static VALUE
define_not_implemented(int argc, VALUE *argv, VALUE mod)
{
    for (int i = 0; i < argc; ++i) {
        rb_define_method_id(mod, rb_to_id(argv[i]), rb_f_notimplement, -1);
    }
    return mod;
}

void
Init_not_implemented(void)
{
    rb_define_method(rb_cModule, "not_implemented", define_not_implemented, -1);
}
