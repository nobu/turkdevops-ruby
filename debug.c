/**********************************************************************

  debug.c -

  $Author$
  created at: 04/08/25 02:31:54 JST

  Copyright (C) 2004-2007 Koichi Sasada

**********************************************************************/

#include "ruby/3/config.h"

#include <stdio.h>

#include "eval_intern.h"
#include "id.h"
#include "internal/signal.h"
#include "internal/util.h"
#include "ruby/encoding.h"
#include "ruby/io.h"
#include "ruby/ruby.h"
#include "ruby/util.h"
#include "symbol.h"
#include "vm_core.h"
#include "vm_debug.h"
#include "vm_callinfo.h"

/* This is the only place struct RIMemo is actually used */
struct RIMemo {
    VALUE flags;
    VALUE v0;
    VALUE v1;
    VALUE v2;
    VALUE v3;
};

/* for gdb */
const union {
    enum ruby_special_consts    special_consts;
    enum ruby_value_type        value_type;
    enum ruby_tag_type          tag_type;
    enum node_type              node_type;
    enum ruby_method_ids        method_ids;
    enum ruby_id_types          id_types;
    enum ruby_fl_type           fl_types;
    enum ruby_fl_ushift         fl_ushift;
    enum ruby_encoding_consts   encoding_consts;
    enum ruby_coderange_type    enc_coderange_types;
    enum ruby_econv_flag_type   econv_flag_types;
    rb_econv_result_t           econv_result;
    enum ruby_robject_flags     robject_flags;
    enum ruby_robject_consts    robject_consts;
    enum ruby_rmodule_flags     rmodule_flags;
    enum ruby_rstring_flags     rstring_flags;
    enum ruby_rstring_consts    rstring_consts;
    enum ruby_rarray_flags      rarray_flags;
    enum ruby_rarray_consts     rarray_consts;
    enum {
	RUBY_FMODE_READABLE		= FMODE_READABLE,
	RUBY_FMODE_WRITABLE		= FMODE_WRITABLE,
	RUBY_FMODE_READWRITE		= FMODE_READWRITE,
	RUBY_FMODE_BINMODE		= FMODE_BINMODE,
	RUBY_FMODE_SYNC 		= FMODE_SYNC,
	RUBY_FMODE_TTY			= FMODE_TTY,
	RUBY_FMODE_DUPLEX		= FMODE_DUPLEX,
	RUBY_FMODE_APPEND		= FMODE_APPEND,
	RUBY_FMODE_CREATE		= FMODE_CREATE,
	RUBY_FMODE_NOREVLOOKUP		= 0x00000100,
	RUBY_FMODE_TRUNC		= FMODE_TRUNC,
	RUBY_FMODE_TEXTMODE		= FMODE_TEXTMODE,
	RUBY_FMODE_PREP 		= 0x00010000,
	RUBY_FMODE_SETENC_BY_BOM	= FMODE_SETENC_BY_BOM,
	RUBY_FMODE_UNIX 		= 0x00200000,
	RUBY_FMODE_INET 		= 0x00400000,
	RUBY_FMODE_INET6		= 0x00800000,

        RUBY_NODE_TYPESHIFT = NODE_TYPESHIFT,
        RUBY_NODE_TYPEMASK  = NODE_TYPEMASK,
        RUBY_NODE_LSHIFT    = NODE_LSHIFT,
        RUBY_NODE_FL_NEWLINE   = NODE_FL_NEWLINE
    } various;
    union {
	enum imemo_type                     types;
	enum {RUBY_IMEMO_MASK = IMEMO_MASK} mask;
	struct RIMemo                      *ptr;
    } imemo;
    struct RSymbol *symbol_ptr;
    enum vm_call_flag_bits vm_call_flags;
} ruby_dummy_gdb_enums;

const SIGNED_VALUE RUBY_NODE_LMASK = NODE_LMASK;

int
ruby_debug_print_indent(int level, int debug_level, int indent_level)
{
    if (level < debug_level) {
	fprintf(stderr, "%*s", indent_level, "");
	fflush(stderr);
	return TRUE;
    }
    return FALSE;
}

void
ruby_debug_printf(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

#include "gc.h"

VALUE
ruby_debug_print_value(int level, int debug_level, const char *header, VALUE obj)
{
    if (level < debug_level) {
	char buff[0x100];
	rb_raw_obj_info(buff, 0x100, obj);

	fprintf(stderr, "DBG> %s: %s\n", header, buff);
	fflush(stderr);
    }
    return obj;
}

void
ruby_debug_print_v(VALUE v)
{
    ruby_debug_print_value(0, 1, "", v);
}

ID
ruby_debug_print_id(int level, int debug_level, const char *header, ID id)
{
    if (level < debug_level) {
	fprintf(stderr, "DBG> %s: %s\n", header, rb_id2name(id));
	fflush(stderr);
    }
    return id;
}

NODE *
ruby_debug_print_node(int level, int debug_level, const char *header, const NODE *node)
{
    if (level < debug_level) {
	fprintf(stderr, "DBG> %s: %s (%u)\n", header,
		ruby_node_name(nd_type(node)), nd_line(node));
    }
    return (NODE *)node;
}

void
ruby_debug_breakpoint(void)
{
    /* */
}

#if defined _WIN32
# if RUBY_MSVCRT_VERSION >= 80
extern int ruby_w32_rtc_error;
# endif
#endif
#if defined _WIN32 || defined __CYGWIN__
#include <windows.h>
UINT ruby_w32_codepage[2];
#endif
extern int ruby_rgengc_debug;
extern int ruby_on_ci;

// Using str, len and separator
#define NAME_MATCH_VALUE(name)				\
    ((size_t)len >= sizeof(name)-1 &&			\
     strncmp(str, (name), sizeof(name)-1) == 0 &&	\
     ((len == sizeof(name)-1 && !(len = 0)) ||		\
      (str[sizeof(name)-1] == separator &&              \
       (str += sizeof(name), len -= sizeof(name), 1))))

#if USE_RUBY_DEBUG_LOG
#define MAX_DEBUG_LOG             0x1000
#define MAX_DEBUG_LOG_MESSAGE_LEN 0x0200
enum ruby_debug_log_mode {
    ruby_debug_log_memory = 1,
    ruby_debug_log_stderr = 2,
    ruby_debug_log_file = 4
} ruby_debug_log_mode;
static char ruby_debug_log_buff[MAX_DEBUG_LOG][MAX_DEBUG_LOG_MESSAGE_LEN];
static volatile rb_atomic_t ruby_debug_log_cnt;
static FILE *ruby_debug_log_output;
#endif

static void
setup_debug_log(const char *str, int len)
{
    static const char separator = ':';
    // fprintf(stderr, "log_config: %*s\n", len, str);
    while (len > 0) {
#if USE_RUBY_DEBUG_LOG
        if (NAME_MATCH_VALUE("mem")) {
            ruby_debug_log_mode |= ruby_debug_log_memory;
            continue;
        }
        if (NAME_MATCH_VALUE("err")) {
            ruby_debug_log_mode |= ruby_debug_log_stderr;
            continue;
        }
        if (NAME_MATCH_VALUE("file")) {
            char fname[0x200];
            snprintf(fname, sizeof(fname), "/tmp/ruby_debug_log.%d.%u", (int)getpid(), (unsigned int)clock());
            ruby_debug_log_output = fopen(fname, "w");
            ruby_debug_log_mode |= ruby_debug_log_file;
            continue;
        }
#endif // USE_RUBY_DEBUG_LOG
        fprintf(stderr, "ignored log option: `%.*s'\n", len, str);
        break;
    }
}

void
ruby_debug_log(const char *file, int line, const char *func_name, const char *fmt, ...)
{
#if USE_RUBY_DEBUG_LOG
    char buff[sizeof(ruby_debug_log_buff[0])];
    int len = 0;
    int r;

#define APPEND_LOG(f,...) do {                                          \
            r = f##snprintf(buff + len, sizeof(buff) - len, __VA_ARGS__); \
            if (r < 0) rb_bug("ruby_debug_log returns %d\n", r); \
            len += r; \
        } while(0)
#define REST_P (len < (int)(sizeof(buff)-1))

    if (file) {
        APPEND_LOG(, "%s:%d ", file, line);
    }

    if (REST_P) {
        int ruby_line;
        const char *ruby_file = rb_source_location_cstr(&ruby_line);
        if (ruby_file) {
            APPEND_LOG(, "%s:%d ", ruby_file, ruby_line);
        }
    }

    if (func_name && REST_P) {
        APPEND_LOG(, "%s ", func_name);
    }

    if (fmt && REST_P) {
        va_list args;
        va_start(args, fmt);
        APPEND_LOG(v, fmt, args);
        va_end(args);
    }

    if (REST_P) {
        memset(buff + len, '\0', sizeof(buff) - len);
    }

    rb_atomic_t cnt = ATOMIC_FETCH_ADD(ruby_debug_log_cnt, 1);
    strncpy(ruby_debug_log_buff[cnt % MAX_DEBUG_LOG], buff, sizeof(buff));

    if (ruby_debug_log_mode & ruby_debug_log_stderr) {
        fprintf(stderr, "%d %s\n", (int)cnt, buff);
    }
    if (ruby_debug_log_mode & ruby_debug_log_file) {
        fprintf(ruby_debug_log_output, "%d %s\n", (int)cnt, buff);
    }
#endif
}

#if USE_RUBY_DEBUG_LOG
// for debugger
void
ruby_debug_log_print(int n)
{
    rb_atomic_t cnt = ruby_debug_log_cnt;
    int size = cnt > MAX_DEBUG_LOG ? MAX_DEBUG_LOG : (int)cnt;
    if (n <= 0 || n > size) n = size;

    for (rb_atomic_t i=cnt-n; i<cnt; i++) {
        const char *mesg = ruby_debug_log_buff[i % MAX_DEBUG_LOG];
        fprintf(stderr, "%d %s\n", (int)i, mesg);
    }
}
#endif // USE_RUBY_DEBUG_LOG

int
ruby_env_debug_option(const char *str, int len, void *arg)
{
    static const char separator = '=';
    int ov;
    size_t retlen;
    unsigned long n;
#define SET_WHEN(name, var, val) do {	    \
	if (len == sizeof(name) - 1 &&	    \
	    strncmp(str, (name), len) == 0) { \
	    (var) = (val);		    \
	    return 1;			    \
	}				    \
    } while (0)
#define SET_UINT(val) do { \
	n = ruby_scan_digits(str, len, 10, &retlen, &ov); \
	if (!ov && retlen) { \
	    val = (unsigned int)n; \
	} \
	str += retlen; \
	len -= retlen; \
    } while (0)
#define SET_UINT_LIST(name, vals, num) do { \
	int i; \
	for (i = 0; i < (num); ++i) { \
	    SET_UINT((vals)[i]); \
	    if (!len || *str != ':') break; \
	    ++str; \
	    --len; \
	} \
	if (len > 0) { \
	    fprintf(stderr, "ignored "name" option: `%.*s'\n", len, str); \
	} \
    } while (0)
#define SET_WHEN_UINT(name, vals, num, req) \
    if (NAME_MATCH_VALUE(name)) SET_UINT_LIST(name, vals, num);

    SET_WHEN("gc_stress", *ruby_initial_gc_stress_ptr, Qtrue);
    SET_WHEN("core", ruby_enable_coredump, 1);
    SET_WHEN("ci", ruby_on_ci, 1);
    if (NAME_MATCH_VALUE("rgengc")) {
	if (!len) ruby_rgengc_debug = 1;
	else SET_UINT_LIST("rgengc", &ruby_rgengc_debug, 1);
	return 1;
    }
    if (NAME_MATCH_VALUE("log")) {
        setup_debug_log(str, len);
        return 1;
    }
#if defined _WIN32
# if RUBY_MSVCRT_VERSION >= 80
    SET_WHEN("rtc_error", ruby_w32_rtc_error, 1);
# endif
#endif
#if defined _WIN32 || defined __CYGWIN__
    if (NAME_MATCH_VALUE("codepage")) {
	if (!len) fprintf(stderr, "missing codepage argument");
	else SET_UINT_LIST("codepage", ruby_w32_codepage, numberof(ruby_w32_codepage));
	return 1;
    }
#endif
    return 0;
}

static void
set_debug_option(const char *str, int len, void *arg)
{
    if (!ruby_env_debug_option(str, len, arg)) {
	fprintf(stderr, "unexpected debug option: %.*s\n", len, str);
    }
}

void
ruby_set_debug_option(const char *str)
{
    ruby_each_words(str, set_debug_option, 0);
}
