#include "ruby/internal/config.h"
#include "internal/abi.h"

#ifdef RUBY_DLN_CHECK_ABI

RUBY_FUNC_EXPORTED unsigned long long __attribute__((weak))
ruby_abi_version(void)
{
    return RUBY_ABI_VERSION;
}

#endif
