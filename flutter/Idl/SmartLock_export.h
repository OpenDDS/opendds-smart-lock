
// -*- C++ -*-
// Definition for Win32 Export directives.
// This file is generated automatically by generate_export_file.pl SmartLock
// ------------------------------
#ifndef SMARTLOCK_EXPORT_H
#define SMARTLOCK_EXPORT_H

#include "ace/config-all.h"

#if defined (ACE_AS_STATIC_LIBS) && !defined (SMARTLOCK_HAS_DLL)
#  define SMARTLOCK_HAS_DLL 0
#endif /* ACE_AS_STATIC_LIBS && SMARTLOCK_HAS_DLL */

#if !defined (SMARTLOCK_HAS_DLL)
#  define SMARTLOCK_HAS_DLL 1
#endif /* ! SMARTLOCK_HAS_DLL */

#if defined (SMARTLOCK_HAS_DLL) && (SMARTLOCK_HAS_DLL == 1)
#  if defined (SMARTLOCK_BUILD_DLL)
#    define SmartLock_Export ACE_Proper_Export_Flag
#    define SMARTLOCK_SINGLETON_DECLARATION(T) ACE_EXPORT_SINGLETON_DECLARATION (T)
#    define SMARTLOCK_SINGLETON_DECLARE(SINGLETON_TYPE, CLASS, LOCK) ACE_EXPORT_SINGLETON_DECLARE(SINGLETON_TYPE, CLASS, LOCK)
#  else /* SMARTLOCK_BUILD_DLL */
#    define SmartLock_Export ACE_Proper_Import_Flag
#    define SMARTLOCK_SINGLETON_DECLARATION(T) ACE_IMPORT_SINGLETON_DECLARATION (T)
#    define SMARTLOCK_SINGLETON_DECLARE(SINGLETON_TYPE, CLASS, LOCK) ACE_IMPORT_SINGLETON_DECLARE(SINGLETON_TYPE, CLASS, LOCK)
#  endif /* SMARTLOCK_BUILD_DLL */
#else /* SMARTLOCK_HAS_DLL == 1 */
#  define SmartLock_Export
#  define SMARTLOCK_SINGLETON_DECLARATION(T)
#  define SMARTLOCK_SINGLETON_DECLARE(SINGLETON_TYPE, CLASS, LOCK)
#endif /* SMARTLOCK_HAS_DLL == 1 */

// Set SMARTLOCK_NTRACE = 0 to turn on library specific tracing even if
// tracing is turned off for ACE.
#if !defined (SMARTLOCK_NTRACE)
#  if (ACE_NTRACE == 1)
#    define SMARTLOCK_NTRACE 1
#  else /* (ACE_NTRACE == 1) */
#    define SMARTLOCK_NTRACE 0
#  endif /* (ACE_NTRACE == 1) */
#endif /* !SMARTLOCK_NTRACE */

#if (SMARTLOCK_NTRACE == 1)
#  define SMARTLOCK_TRACE(X)
#else /* (SMARTLOCK_NTRACE == 1) */
#  if !defined (ACE_HAS_TRACE)
#    define ACE_HAS_TRACE
#  endif /* ACE_HAS_TRACE */
#  define SMARTLOCK_TRACE(X) ACE_TRACE_IMPL(X)
#  include "ace/Trace.h"
#endif /* (SMARTLOCK_NTRACE == 1) */

#endif /* SMARTLOCK_EXPORT_H */

// End of auto generated file.
