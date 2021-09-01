// This file is a part of Julia. License is MIT: https://julialang.org/license
// Bring in the curated lists of exported data and function symbols, then
// perform C preprocessor magic upon them to generate lists of declarations and
// functions to re-export our function symbols from libjulia-internal to libjulia.
#include "../src/jl_exported_data.inc"
#include "../src/jl_exported_funcs.inc"

// Define pointer data as `const void * $(name);`
#define XX(name)    JL_DLLEXPORT const void * name;
JL_EXPORTED_DATA_POINTERS(XX)
#ifdef _OS_WINDOWS_
JL_EXPORTED_DATA_POINTERS_WIN(XX)
#endif
#undef XX

// Define symbol data as `$(type) $(name);`
#define XX(name, type)    JL_DLLEXPORT type name;
JL_EXPORTED_DATA_SYMBOLS(XX)
#ifdef _OS_WINDOWS_
JL_EXPORTED_DATA_SYMBOLS_WIN(XX)
#endif
#undef XX

#ifndef HAVE_SSP
JL_DLLEXPORT size_t __stack_chk_guard;
#endif

// Declare list of exported functions (sans type)
#define XX(name)    JL_DLLEXPORT void name(void);
typedef void (anonfunc)(void);
JL_RUNTIME_EXPORTED_FUNCS(XX)
#ifdef _OS_WINDOWS_
JL_RUNTIME_EXPORTED_FUNCS_WIN(XX)
// needs to be special-cased due to name mangling
JL_DLLEXPORT void NTAPI __julia_personality(void);
#endif
JL_CODEGEN_EXPORTED_FUNCS(XX)
#undef XX

// Define holder locations for function addresses as `const void * $(name)_addr = & $(name);`
#define XX(name)    JL_HIDDEN anonfunc * name##_addr = (anonfunc*)&name;
JL_RUNTIME_EXPORTED_FUNCS(XX)
#ifdef _OS_WINDOWS_
JL_RUNTIME_EXPORTED_FUNCS_WIN(XX)
JL_HIDDEN anonfunc * __julia_personality_addr = NULL;
#endif
JL_CODEGEN_EXPORTED_FUNCS(XX)
#undef XX

#define XX(name)    JL_DLLEXPORT anonfunc * name##_addr;
JL_RUNTIME_EXPORTED_FUNC_ADDRS(XX)
#undef XX

// Generate lists of function names and addresses
#define XX(name)    #name,
static const char *const jl_runtime_exported_func_names[] = {
    JL_RUNTIME_EXPORTED_FUNCS(XX)
#ifdef _OS_WINDOWS_
    JL_RUNTIME_EXPORTED_FUNCS_WIN(XX)
    "__julia_personality@16",
#endif
    JL_RUNTIME_EXPORTED_FUNC_ADDRS(XX)
    NULL
};
#undef XX
#define XX(name)    #name"_impl",
static const char *const jl_codegen_exported_func_names[] = {
    JL_CODEGEN_EXPORTED_FUNCS(XX)
    NULL
};
#undef XX

#define XX(name)    &name##_addr,
static anonfunc **const jl_runtime_exported_func_addrs[] = {
    JL_RUNTIME_EXPORTED_FUNCS(XX)
#ifdef _OS_WINDOWS_
    JL_RUNTIME_EXPORTED_FUNCS_WIN(XX)
    &__julia_personality_addr,
#endif
    JL_RUNTIME_EXPORTED_FUNC_ADDRS(XX)
    NULL
};
static anonfunc **const jl_codegen_exported_func_addrs[] = {
    JL_CODEGEN_EXPORTED_FUNCS(XX)
    NULL
};
#undef XX
