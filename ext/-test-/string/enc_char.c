#include "ruby/ruby.h"
#include "ruby/encoding.h"

static VALUE
enc_left_char_head(VALUE str, VALUE idx)
{
    const char *ptr, *left;
    long len, pos = NUM2INT(idx);
    rb_encoding *enc = rb_enc_get(str);
    RSTRING_GETMEM(str, ptr, len);
    left = rb_enc_left_char_head(ptr, ptr+pos, ptr+len, enc);
    return SSIZET2NUM(left - ptr);
}

void
Init_string_enc_char(VALUE klass)
{
    rb_define_method(klass, "enc_left_char_head", enc_left_char_head, 1);
}
