# This is a custom file written for .NET Core's build system
# It overwrites the one found in upstream
project(unwind)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

# The HAVE___THREAD set to 1 causes creation of thread local variable with tls_model("initial-exec")
# which is incompatible with usage of the unwind code in a shared library.
add_definitions(-DHAVE___THREAD=0)

add_definitions(-D_GNU_SOURCE)

add_definitions(-DPACKAGE_STRING="")
add_definitions(-DPACKAGE_BUGREPORT="")


if(CLR_CMAKE_HOST_UNIX)
    if (CLR_CMAKE_HOST_ARCH_AMD64)
      set(arch x86_64)
    elseif(CLR_CMAKE_HOST_ARCH_ARM64)
      set(arch aarch64)
    elseif(CLR_CMAKE_HOST_ARCH_ARM)
      set(arch arm)
    elseif(CLR_CMAKE_HOST_ARCH_ARMV6)
      set(arch arm)
    elseif(CLR_CMAKE_HOST_ARCH_I386)
        set(arch x86)
    elseif(CLR_CMAKE_HOST_ARCH_S390X)
      set(arch s390x)
    elseif(CLR_CMAKE_HOST_ARCH_LOONGARCH64)
      set(arch loongarch64)
    endif ()

    # Disable warning due to incorrect format specifier in debugging printf via the Debug macro
    add_compile_options(-Wno-format -Wno-format-security)
    add_compile_options(-Wno-implicit-fallthrough)

    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
      add_compile_options(-Wno-header-guard)
    else()
      add_compile_options(-Wno-unused-value)
      add_compile_options(-Wno-unused-result)
      add_compile_options(-Wno-implicit-function-declaration)
      add_compile_options(-Wno-incompatible-pointer-types)
    endif()

    if(CLR_CMAKE_HOST_ARCH_ARM OR CLR_CMAKE_HOST_ARCH_ARMV6)
        # Ensure that the remote and local unwind code can reside in the same binary without name clashing
        add_definitions("-Darm_search_unwind_table=UNW_OBJ(arm_search_unwind_table)")
        if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            # Disable warning due to labs function called on unsigned argument
            add_compile_options(-Wno-absolute-value)
            # Disable warning in asm: use of SP or PC in the list is deprecated
            add_compile_options(-Wno-inline-asm)
        endif()
        # Disable warning for a bug in the libunwind source src/arm/Gtrace.c:529, but not in code that we exercise
        add_compile_options(-Wno-implicit-function-declaration)
        # Disable warning due to an unused function prel31_read
        add_compile_options(-Wno-unused-function)
        # We compile code with -std=c99 and the asm keyword is not recognized as it is a gnu extension
        add_definitions(-Dasm=__asm__)
    elseif(CLR_CMAKE_HOST_ARCH_ARM64)
        if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            # Disable warning due to labs function called on unsigned argument
            add_compile_options(-Wno-absolute-value)
        endif()
        # We compile code with -std=c99 and the asm keyword is not recognized as it is a gnu extension
        add_definitions(-Dasm=__asm__)
        # Disable warning for a bug in the libunwind source src/aarch64/Ginit.c, but not in code that we exercise
        add_compile_options(-Wno-incompatible-pointer-types)
    elseif(CLR_CMAKE_HOST_ARCH_I386)
        # Disable warning for a bug in the libunwind source src/x86/Gos-linux.c, but not in code that we exercise
        add_compile_options(-Wno-incompatible-pointer-types)
    elseif(CLR_CMAKE_HOST_ARCH_LOONGARCH64)
        ###TODO: maybe add options for LOONGARCH64
    endif()

    if (CLR_CMAKE_HOST_OSX)
        add_definitions(-DUNW_REMOTE_ONLY)
        add_compile_options(-Wno-sometimes-uninitialized)
        add_compile_options(-Wno-implicit-function-declaration)

        # Our posix abstraction layer will provide these headers
        set(HAVE_ELF_H 1)
        set(HAVE_ENDIAN_H 1)
    endif(CLR_CMAKE_HOST_OSX)

endif(CLR_CMAKE_HOST_UNIX)

if(CLR_CMAKE_HOST_WIN32)
    if (CLR_CMAKE_TARGET_ARCH_AMD64)
      set(TARGET_AMD64 1)
      set(arch x86_64)
      add_definitions(-D__x86_64__)
      add_definitions(-D__amd64__)
    elseif(CLR_CMAKE_TARGET_ARCH_ARM64)
      set(TARGET_AARCH64 1)
      set(arch aarch64)
      add_definitions(-D__aarch64__)
    elseif(CLR_CMAKE_TARGET_ARCH_ARM)
      set(TARGET_ARM 1)
      set(arch arm)
      add_definitions(-D__arm__)
    elseif(CLR_CMAKE_TARGET_ARCH_ARMV6)
      set(TARGET_ARM 1)
      set(arch arm)
      add_definitions(-D__arm__)
    elseif(CLR_CMAKE_TARGET_ARCH_S390X)
      set(TARGET_S390X 1)
      set(arch s390x)
      add_definitions(-D__s390x__)
    else ()
      message(FATAL_ERROR "Unrecognized TARGET")
    endif ()

    # Windows builds will only support remote unwind
    add_definitions(-DUNW_REMOTE_ONLY)

    add_definitions(-DHAVE_UNW_GET_ACCESSORS)

    # Disable security warnings
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)

    if(CLR_CMAKE_TARGET_LINUX)
      add_definitions(-D__linux__)
    endif ()

    # Assume we are using default MSVC compiler
    add_compile_options(/TC) # compile all files as C
    add_compile_options(/permissive-)

    # include paths
    include_directories(${CLR_SRC_NATIVE_DIR}/external/libunwind/include/tdep)
    include_directories(${CLR_SRC_NATIVE_DIR}/external/libunwind/include)
    include_directories(${CLR_ARTIFACTS_OBJ_DIR}/external/libunwind/include/tdep)
    include_directories(${CLR_ARTIFACTS_OBJ_DIR}/external/libunwind/include)

    # files for cross os compilation
    include_directories(${CLR_SRC_NATIVE_DIR}/external/libunwind/include/win)

    add_definitions(-D_CRT_DECLARE_NONSTDC_NAMES)

    # Warnings in release builds
    add_compile_options(-wd4068) # ignore unknown pragma warnings (gcc pragmas)
    add_compile_options(-wd4244) # possible loss of data
    add_compile_options(-wd4334) # 32-bit shift implicitly converted to 64 bits

    # Disable warning due to incorrect format specifier in debugging printf via the Debug macro
    add_compile_options(-wd4311) # pointer truncation from 'unw_word_t *' to 'long'
    add_compile_options(-wd4475) # 'fprintf' : length modifier 'L' cannot be used
    add_compile_options(-wd4477) # fprintf argument type
endif (CLR_CMAKE_HOST_WIN32)

if(CLR_CMAKE_TARGET_ARCH_ARM OR CLR_CMAKE_TARGET_ARCH_ARMV6)
    # The arm sources include ex_tables.h from include/tdep-arm without going through a redirection
    # in include/tdep like it works for similar files on other architectures. So we need to add
    # the include/tdep-arm to include directories
    include_directories(${CLR_SRC_NATIVE_DIR}/external/libunwind/include/tdep-arm)
endif()

include(configure.cmake)
include(${CLR_SRC_NATIVE_DIR}/external/libunwind.cmake)

set(LIBUNWIND_SOURCES
  ${LIBUNWIND_SOURCES}
  ${CMAKE_CURRENT_LIST_DIR}/oop/_OOP_find_proc_info.c)

if(CLR_CMAKE_HOST_UNIX)
    if(CLR_CMAKE_HOST_OSX)
        include_directories(${CMAKE_CURRENT_LIST_DIR}/mac)
        add_library(libunwind_dac OBJECT
          ${CMAKE_CURRENT_LIST_DIR}/mac/missing-functions.c
          ${LIBUNWIND_SOURCES})
    else()
        add_library(libunwind OBJECT ${LIBUNWIND_SOURCES})
    endif(CLR_CMAKE_HOST_OSX)
else(CLR_CMAKE_HOST_UNIX)
    add_library(libunwind_xdac OBJECT
      ${CLR_DIR}/pal/src/exception/remote-unwind.cpp
      ${LIBUNWIND_SOURCES})
endif(CLR_CMAKE_HOST_UNIX)
