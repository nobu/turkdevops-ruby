#include "ruby.h"
#include "ruby/encoding.h"
#include "ruby/util.h"
#include "../date_tmx.h"

VALUE date_zone_to_diff(VALUE);
VALUE date__iso8601(VALUE);
VALUE date_new_by_frags(VALUE klass, VALUE hash, VALUE sg);
VALUE datetime_new_by_frags(VALUE klass, VALUE hash, VALUE sg);
VALUE datetime_iso8601_timediv(VALUE self, long n);
VALUE datetime_strftime_tmx(const char *fmt, VALUE self,
                            void (*func)(VALUE, struct tmx *));
void datetime_set_tmx(VALUE self, struct tmx *tmx);
VALUE datetime_iso8601_timediv(VALUE self, long n);

#define strftimev datetime_strftime_tmx
#define set_tmx datetime_set_tmx
#define iso8601_timediv datetime_iso8601_timediv

#define ITALY 2299161 /* 1582-10-15 */
#define ENGLAND 2361222 /* 1752-09-14 */
#define JULIAN positive_inf
#define GREGORIAN negative_inf
#define DEFAULT_SG ITALY

#define f_jd(x) rb_funcallv(x, rb_intern("jd"), 0, 0)
#define f_year(x) rb_funcallv(x, rb_intern("year"), 0, 0)
#define f_negate(x) rb_funcall(x, rb_intern("-@"), 0)
#define f_add(x,y) rb_funcall(x, '+', 1, y)
#define f_sub(x,y) rb_funcall(x, '-', 1, y)
#define f_mul(x,y) rb_funcall(x, '*', 1, y)
#define f_div(x,y) rb_funcall(x, '/', 1, y)
#define f_idiv(x,y) rb_funcall(x, rb_intern("div"), 1, y)
#define f_mod(x,y) rb_funcall(x, '%', 1, y)
#define f_expt(x,y) rb_funcall(x, rb_intern("**"), 1, y)

#define f_lt_p(x,y) rb_funcall(x, '<', 1, y)
#define f_gt_p(x,y) rb_funcall(x, '>', 1, y)
#define f_le_p(x,y) rb_funcall(x, rb_intern("<="), 1, y)
#define f_ge_p(x,y) rb_funcall(x, rb_intern(">="), 1, y)

#define f_to_s(x) rb_funcall(x, rb_intern("to_s"), 0)

#define f_match(r,s) rb_funcall(r, rb_intern("match"), 1, s)
#define f_aref(o,i) rb_funcall(o, rb_intern("[]"), 1, i)
#define f_aref2(o,i,j) rb_funcall(o, rb_intern("[]"), 2, i, j)
#define f_begin(o,i) rb_funcall(o, rb_intern("begin"), 1, i)
#define f_end(o,i) rb_funcall(o, rb_intern("end"), 1, i)
#define f_aset(o,i,v) rb_funcall(o, rb_intern("[]="), 2, i, v)
#define f_aset2(o,i,j,v) rb_funcall(o, rb_intern("[]="), 3, i, j, v)
#define f_sub_bang(s,r,x) rb_funcall(s, rb_intern("sub!"), 2, r, x)
#define f_gsub_bang(s,r,x) rb_funcall(s, rb_intern("gsub!"), 2, r, x)

#define set_hash(k,v) rb_hash_aset(hash, ID2SYM(rb_intern(k"")), v)
#define ref_hash(k) rb_hash_aref(hash, ID2SYM(rb_intern(k"")))
#define del_hash(k) rb_hash_delete(hash, ID2SYM(rb_intern(k"")))

#define cstr2num(s) rb_cstr_to_inum(s, 10, 0)
#define str2num(s) rb_str_to_inum(s, 10, 0)

/* parser */

#define issign(c) ((c) == '-' || (c) == '+')
#define asp_string() rb_str_new(" ", 1)
#ifdef TIGHT_PARSER
#define asuba_string() rb_str_new("\001", 1)
#define asubb_string() rb_str_new("\002", 1)
#define asubw_string() rb_str_new("\027", 1)
#define asubt_string() rb_str_new("\024", 1)
#endif

#ifdef TIGHT_PARSER
#define BOS "\\A\\s*"
#define FPA "\\001"
#define FPB "\\002"
#define FPW "\\027"
#define FPT "\\024"
#define FPW_COM "\\s*(?:" FPW "\\s*,?)?\\s*"
#define FPT_COM "\\s*(?:" FPT "\\s*,?)?\\s*"
#define COM_FPW "\\s*(?:,?\\s*" FPW ")?\\s*"
#define COM_FPT "\\s*(?:,?\\s*(?:@|\\b[aA][tT]\\b)?\\s*" FPT ")?\\s*"
#define TEE_FPT "\\s*(?:[tT]?" FPT ")?"
#define EOS "\\s*\\z"
#endif

static VALUE
regcomp(const char *source, long len, int opt)
{
    VALUE pat;

    pat = rb_reg_new(source, len, opt);
    rb_gc_register_mark_object(pat);
    return pat;
}

#define REGCOMP(pat,opt) \
do { \
    if (NIL_P(pat)) \
	pat = regcomp(pat##_source, sizeof pat##_source - 1, opt); \
} while (0)

#define REGCOMP_0(pat) REGCOMP(pat, 0)
#define REGCOMP_I(pat) REGCOMP(pat, ONIG_OPTION_IGNORECASE)

#define MATCH(s,p,c) \
do { \
    return match(s, p, hash, c); \
} while (0)

static int
match(VALUE str, VALUE pat, VALUE hash, int (*cb)(VALUE, VALUE))
{
    VALUE m;

    m = f_match(pat, str);

    if (NIL_P(m))
	return 0;

    (*cb)(m, hash);

    return 1;
}

static int
subx(VALUE str, VALUE rep, VALUE pat, VALUE hash, int (*cb)(VALUE, VALUE))
{
    VALUE m;

    m = f_match(pat, str);

    if (NIL_P(m))
	return 0;

    {
	VALUE be, en;

	be = f_begin(m, INT2FIX(0));
	en = f_end(m, INT2FIX(0));
	f_aset2(str, be, LONG2NUM(NUM2LONG(en) - NUM2LONG(be)), rep);
	(*cb)(m, hash);
    }

    return 1;
}

#define SUBS(s,p,c) \
do { \
    return subx(s, asp_string(), p, hash, c); \
} while (0)

#ifdef TIGHT_PARSER
#define SUBA(s,p,c) \
do { \
    return subx(s, asuba_string(), p, hash, c); \
} while (0)

#define SUBB(s,p,c) \
do { \
    return subx(s, asubb_string(), p, hash, c); \
} while (0)

#define SUBW(s,p,c) \
do { \
    return subx(s, asubw_string(), p, hash, c); \
} while (0)

#define SUBT(s,p,c) \
do { \
    return subx(s, asubt_string(), p, hash, c); \
} while (0)
#endif

#define HAVE_ALPHA (1<<0)
#define HAVE_DIGIT (1<<1)
#define HAVE_DASH (1<<2)
#define HAVE_DOT (1<<3)
#define HAVE_SLASH (1<<4)

#define HAVE_ELEM_P(x) ((elem_class & (x)) == (x))

#define JISX0301_ERA_INITIALS "mtsh"
#define JISX0301_DEFAULT_ERA 'H' /* obsolete */

static int
gengo(int c)
{
    int e;

    switch (c) {
      case 'M': case 'm': e = 1867; break;
      case 'T': case 't': e = 1911; break;
      case 'S': case 's': e = 1925; break;
      case 'H': case 'h': e = 1988; break;
      default:  e = 0; break;
    }
    return e;
}

static int
parse_jis_cb(VALUE m, VALUE hash)
{
    VALUE e, y, mon, d;
    int ep;

    e = rb_reg_nth_match(1, m);
    y = rb_reg_nth_match(2, m);
    mon = rb_reg_nth_match(3, m);
    d = rb_reg_nth_match(4, m);

    ep = gengo(*RSTRING_PTR(e));

    set_hash("year", f_add(str2num(y), INT2FIX(ep)));
    set_hash("mon", str2num(mon));
    set_hash("mday", str2num(d));

    return 1;
}

static int
parse_jis(VALUE str, VALUE hash)
{
    static const char pat_source[] =
#ifndef TIGHT_PARSER
        "\\b([" JISX0301_ERA_INITIALS "])(\\d+)\\.(\\d+)\\.(\\d+)"
#else
	BOS
	FPW_COM FPT_COM
        "([" JISX0301_ERA_INITIALS "])(\\d+)\\.(\\d+)\\.(\\d+)"
	TEE_FPT COM_FPW
	EOS
#endif
	;
    static VALUE pat = Qnil;

    REGCOMP_I(pat);
    SUBS(str, pat, parse_jis_cb);
}

static VALUE
jisx301___parse(VALUE self, VALUE str, VALUE hash, VALUE ec)
{
    unsigned elem_class = NUM2UINT(ec);
    VALUE args[3] = {str, hash, ec};
    if (HAVE_ELEM_P(HAVE_DIGIT|HAVE_DOT))
	parse_jis(str, hash);
    return rb_call_super(3, args);
}

static VALUE
sec_fraction(VALUE f)
{
    return rb_rational_new2(str2num(f),
			    f_expt(INT2FIX(10),
				   LONG2NUM(RSTRING_LEN(f))));
}

#define SNUM 9

static int
jisx0301_cb(VALUE m, VALUE hash)
{
    VALUE s[SNUM + 1];
    int ep;

    {
	int i;
	s[0] = Qnil;
	for (i = 1; i <= SNUM; i++)
	    s[i] = rb_reg_nth_match(i, m);
    }

    ep = gengo(NIL_P(s[1]) ? JISX0301_DEFAULT_ERA : *RSTRING_PTR(s[1]));
    set_hash("year", f_add(str2num(s[2]), INT2FIX(ep)));
    set_hash("mon", str2num(s[3]));
    set_hash("mday", str2num(s[4]));
    if (!NIL_P(s[5])) {
	set_hash("hour", str2num(s[5]));
	if (!NIL_P(s[6]))
	    set_hash("min", str2num(s[6]));
	if (!NIL_P(s[7]))
	    set_hash("sec", str2num(s[7]));
    }
    if (!NIL_P(s[8]))
	set_hash("sec_fraction", sec_fraction(s[8]));
    if (!NIL_P(s[9])) {
	set_hash("zone", s[9]);
	set_hash("offset", date_zone_to_diff(s[9]));
    }

    return 1;
}

static int
jisx0301(VALUE str, VALUE hash)
{
    static const char pat_source[] =
        "\\A\\s*([" JISX0301_ERA_INITIALS "])?(\\d{2})\\.(\\d{2})\\.(\\d{2})"
	"(?:t"
	"(?:(\\d{2}):(\\d{2})(?::(\\d{2})(?:[,.](\\d*))?)?"
	"(z|[-+]\\d{2}(?::?\\d{2})?)?)?)?\\s*\\z";
    static VALUE pat = Qnil;

    REGCOMP_I(pat);
    MATCH(str, pat, jisx0301_cb);
}

VALUE
date__jisx0301(VALUE str)
{
    VALUE backref, hash;

    backref = rb_backref_get();
    rb_match_busy(backref);

    hash = rb_hash_new();
    if (jisx0301(str, hash))
	goto ok;
    hash = date__iso8601(str);

  ok:
    rb_backref_set(backref);
    return hash;
}

/*
 * call-seq:
 *    Date._jisx0301(string)  ->  hash
 *
 * Returns a hash of parsed elements.
 */
static VALUE
date_s__jisx0301(VALUE klass, VALUE str)
{
    return date__jisx0301(str);
}

/*
 * call-seq:
 *    Date.jisx0301(string='-4712-01-01'[, start=Date::ITALY])  ->  date
 *
 * Creates a new Date object by parsing from a string according to
 * some typical JIS X 0301 formats.
 *
 *    Date.jisx0301('H13.02.03')		#=> #<Date: 2001-02-03 ...>
 */
static VALUE
date_s_jisx0301(int argc, VALUE *argv, VALUE klass)
{
    VALUE str, sg;

    rb_scan_args(argc, argv, "02", &str, &sg);

    switch (argc) {
      case 0:
	str = rb_str_new2("-4712-01-01");
      case 1:
	sg = INT2FIX(DEFAULT_SG);
    }

    {
	VALUE hash = date_s__jisx0301(klass, str);
	return date_new_by_frags(klass, hash, sg);
    }
}

/*
 * call-seq:
 *    DateTime.jisx0301(string='-4712-01-01T00:00:00+00:00'[, start=Date::ITALY])  ->  datetime
 *
 * Creates a new DateTime object by parsing from a string according to
 * some typical JIS X 0301 formats.
 *
 *    DateTime.jisx0301('H13.02.03T04:05:06+07:00')
 *				#=> #<DateTime: 2001-02-03T04:05:06+07:00 ...>
 */
static VALUE
datetime_s_jisx0301(int argc, VALUE *argv, VALUE klass)
{
    VALUE str, sg;

    rb_scan_args(argc, argv, "02", &str, &sg);

    switch (argc) {
      case 0:
	str = rb_str_new2("-4712-01-01T00:00:00+00:00");
      case 1:
	sg = INT2FIX(DEFAULT_SG);
    }

    {
	VALUE hash = date_s__jisx0301(klass, str);
	return datetime_new_by_frags(klass, hash, sg);
    }
}

/* formatter */

static const char *
jisx0301_date_format(char *fmt, size_t size, VALUE jd, VALUE y)
{
    if (FIXNUM_P(jd)) {
	long d = FIX2INT(jd);
	long s;
	char c;
	if (d < 2405160)
	    return "%Y-%m-%d";
	if (d < 2419614) {
	    c = 'M';
	    s = 1867;
	}
	else if (d < 2424875) {
	    c = 'T';
	    s = 1911;
	}
	else if (d < 2447535) {
	    c = 'S';
	    s = 1925;
	}
	else {
	    c = 'H';
	    s = 1988;
	}
	snprintf(fmt, size, "%c%02ld" ".%%m.%%d", c, FIX2INT(y) - s);
	return fmt;
    }
    return "%Y-%m-%d";
}

/*
 * call-seq:
 *    d.jisx0301  ->  string
 *
 * Returns a string in a JIS X 0301 format.
 *
 *    Date.new(2001,2,3).jisx0301	#=> "H13.02.03"
 */
static VALUE
d_lite_jisx0301(VALUE self)
{
    char fmtbuf[DECIMAL_SIZE_OF_BITS(CHAR_BIT*sizeof(long))];
    const char *fmt;

    fmt = jisx0301_date_format(fmtbuf, sizeof(fmtbuf),
                               f_jd(self),
			       f_year(self));
    return strftimev(fmt, self, set_tmx);
}

/*
 * call-seq:
 *    dt.jisx0301([n=0])  ->  string
 *
 * Returns a string in a JIS X 0301 format.
 * The optional argument +n+ is the number of digits for fractional seconds.
 *
 *    DateTime.parse('2001-02-03T04:05:06.123456789+07:00').jisx0301(9)
 *				#=> "H13.02.03T04:05:06.123456789+07:00"
 */
static VALUE
dt_lite_jisx0301(int argc, VALUE *argv, VALUE self)
{
    long n = 0;

    rb_check_arity(argc, 0, 1);
    if (argc >= 1)
	n = NUM2LONG(argv[0]);

    return rb_str_append(d_lite_jisx0301(self),
			 iso8601_timediv(self, n));
}

void
Init_jisx0301(void)
{
    rb_require("date_core.so");
    VALUE cDate = rb_path2class("Date");
    VALUE cDateTime = rb_path2class("DateTime");
    VALUE mJISX0301;
    VALUE c;

    mJISX0301 = rb_module_new();
    c = CLASS_OF(cDate);
    rb_prepend_module(c, mJISX0301);
    rb_define_method(mJISX0301, "__parse", jisx301___parse, 3);

    VALUE verbose = ruby_verbose;
    ruby_verbose = Qnil;
    rb_define_singleton_method(cDate, "_jisx0301", date_s__jisx0301, 1);
    rb_define_singleton_method(cDate, "jisx0301", date_s_jisx0301, -1);
    rb_define_method(cDate, "jisx0301", d_lite_jisx0301, 0);

    rb_define_singleton_method(cDateTime, "jisx0301", datetime_s_jisx0301, -1);
    rb_define_method(cDateTime, "jisx0301", dt_lite_jisx0301, -1);
    ruby_verbose = verbose;
}
