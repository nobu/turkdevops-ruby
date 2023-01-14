!ifndef srcdir
srcdir = .
!endif
!ifndef CPP
CPP = cl -EP
!endif
!if exist(revision.h)
revision_h = revision.h
!else if exist($(srcdir)/revision.h)
revision_h = $(srcdir)/revision.h
!else
revision_h =
!endif
verconf.mk: $(revision_h)
	@findstr /R /C:"^#define RUBY_ABI_VERSION " $(srcdir:/=\)\include\ruby\internal\abi.h > $(@)
	@$(CPP) -I$(srcdir) -I$(srcdir)/include <<"Creating $(@)" > $(*F).bat
@echo off
!if "$(revision_h)" == ""
#define RUBY_REVISION 0
!endif
#define STRINGIZE0(expr) #expr
#define STRINGIZE(x) STRINGIZE0(x)
#include "version.h"
#ifdef RUBY_RELEASE_YEAR
set ruby_release_year=RUBY_RELEASE_YEAR
#endif
#ifdef RUBY_RELEASE_MONTH
set ruby_release_month=RUBY_RELEASE_MONTH
#endif
#ifdef RUBY_RELEASE_DAY
set ruby_release_day=RUBY_RELEASE_DAY
#endif
set ruby_release_month=0%ruby_release_month%
set ruby_release_day=0%ruby_release_day%
#undef RUBY_RELEASE_YEAR
#undef RUBY_RELEASE_MONTH
#undef RUBY_RELEASE_DAY
echo RUBY_RELEASE_YEAR = %ruby_release_year%
echo RUBY_RELEASE_MONTH = %ruby_release_month:~-2%
echo RUBY_RELEASE_DAY = %ruby_release_day:~-2%
echo MAJOR = RUBY_VERSION_MAJOR
echo MINOR = RUBY_VERSION_MINOR
echo TEENY = RUBY_VERSION_TEENY
#if defined RUBY_PATCHLEVEL && RUBY_PATCHLEVEL < 0
#include "$(@F)"
echo ABI_VERSION = RUBY_ABI_VERSION
#endif
set /a MSC_VER = _MSC_VER
#if _MSC_VER >= 1920
set /a MSC_VER_LOWER = MSC_VER/20*20+0
set /a MSC_VER_UPPER = MSC_VER/20*20+19
#elif _MSC_VER >= 1900
set /a MSC_VER_LOWER = MSC_VER/10*10+0
set /a MSC_VER_UPPER = MSC_VER/10*10+9
#endif
set MSC_VER
del %0 & exit
<<
	@cmd /c $(*F).bat > $(@)
