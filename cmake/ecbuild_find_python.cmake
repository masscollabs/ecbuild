# (C) Copyright 1996-2016 ECMWF.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
# In applying this licence, ECMWF does not waive the privileges and immunities
# granted to it by virtue of its status as an intergovernmental organisation nor
# does it submit to any jurisdiction.

##############################################################################
#.rst:
#
# ecbuild_find_python
# ===================
#
# Find Python interpreter, its version and the Python libraries. ::
#
#   ecbuild_find_python( [ VERSION <version> ] [ REQUIRED ] [ NO_LIBS ] )
#
# Options
# -------
#
# VERSION : optional
#   minimum required version
#
# REQUIRED : optional
#   fail if Python was not found
#
# NO_LIBS : optional
#   only search for the Python interpreter, not the libraries
#
# Unless ``NO_LIBS`` is set, the ``python-config`` utility, if found, is used
# to determine the Python include directories, libraries and link line. Set the
# CMake variable ``PYTHON_NO_CONFIG`` to use CMake's FindPythonLibs instead.
#
# Output variables
# ----------------
#
# The following CMake variables are set if python was found:
#
# :PYTHONINTERP_FOUND:    Python interpreter was found
# :PYTHONLIBS_FOUND:      Python libraries were found
# :PYTHON_FOUND:          Python was found (both interpreter and libraries)
# :PYTHON_EXECUTABLE:     Python executable
# :PYTHON_VERSION_MAJOR:  major version number
# :PYTHON_VERSION_MINOR:  minor version number
# :PYTHON_VERSION_PATCH:  patch version number
# :PYTHON_VERSION_STRING: Python version
# :PYTHON_INCLUDE_DIRS:   Python include directories
# :PYTHON_LIBRARIES:      Python libraries
# :PYTHON_SITE_PACKAGES:  Python site packages directory
#
##############################################################################

set( __test_python ${CMAKE_CURRENT_LIST_DIR}/pymain.c )

function( ecbuild_find_python )

    # parse parameters

    set( options REQUIRED NO_LIBS )
    set( single_value_args VERSION )
    set( multi_value_args  )

    cmake_parse_arguments( _p "${options}" "${single_value_args}" "${multi_value_args}"  ${_FIRST_ARG} ${ARGN} )

    if(_p_UNPARSED_ARGUMENTS)
      ecbuild_critical("Unknown keywords given to ecbuild_find_python(): \"${_p_UNPARSED_ARGUMENTS}\"")
    endif()
    if( _p_REQUIRED )
      set( _p_REQUIRED REQUIRED )
    else()
      unset( _p_REQUIRED )
    endif()

    # find python executable

    find_package( PythonInterp ${_p_VERSION} ${_p_REQUIRED} )

    set( __required_vars PYTHONINTERP_FOUND )

    if( PYTHONINTERP_FOUND )
        ecbuild_debug( "ecbuild_find_python: Found Python interpreter version ${PYTHON_VERSION_STRING} at ${PYTHON_EXECUTABLE}" )

        # find where python site-packages are ...

        if( PYTHON_EXECUTABLE )
            execute_process(COMMAND ${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())" OUTPUT_VARIABLE PYTHON_SITE_PACKAGES OUTPUT_STRIP_TRAILING_WHITESPACE)
        endif()
        ecbuild_debug( "ecbuild_find_python: PYTHON_SITE_PACKAGES=${PYTHON_SITE_PACKAGES}" )
    endif()

    if( PYTHONINTERP_FOUND AND NOT _p_NO_LIBS )
        list( APPEND __required_vars PYTHONLIBS_FOUND PYTHON_LIBS_WORKING )

        # find python config

        if( PYTHON_EXECUTABLE AND EXISTS ${PYTHON_EXECUTABLE}-config )
            set(PYTHON_CONFIG_EXECUTABLE ${PYTHON_EXECUTABLE}-config CACHE PATH "" FORCE)
        else()
            get_filename_component( __python_bin_dir ${PYTHON_EXECUTABLE} PATH )
            find_program( PYTHON_CONFIG_EXECUTABLE
                          NO_CMAKE_PATH NO_CMAKE_SYSTEM_PATH
                          NO_CMAKE_ENVIRONMENT_PATH NO_SYSTEM_ENVIRONMENT_PATH
                          HINTS ${__python_bin_dir}
                          NAMES python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}-config
                                python${PYTHON_VERSION_MAJOR}-config
                                python-config )
        endif()

        ecbuild_debug_var( PYTHON_CONFIG_EXECUTABLE )

        # find python libs

        # The OpenBSD python packages have python-config's
        # that don't reliably report linking flags that will work.

        if( PYTHON_CONFIG_EXECUTABLE AND NOT ( PYTHON_NO_CONFIG OR ${CMAKE_SYSTEM_NAME} STREQUAL "OpenBSD" ) )
            ecbuild_debug( "ecbuild_find_python: Searching for Python include directories and libraries using ${PYTHON_CONFIG_EXECUTABLE}" )

            if( NOT PYTHON_LIBRARY )
              execute_process(COMMAND "${PYTHON_CONFIG_EXECUTABLE}" --prefix
                              OUTPUT_VARIABLE PYTHON_PREFIX
                              OUTPUT_STRIP_TRAILING_WHITESPACE
                              ERROR_QUIET)

              execute_process(COMMAND "${PYTHON_CONFIG_EXECUTABLE}" --ldflags
                              OUTPUT_VARIABLE PYTHON_LIBRARY
                              OUTPUT_STRIP_TRAILING_WHITESPACE
                              ERROR_QUIET)

              # Prepend -L and and set the RPATH to the lib directory under the
              # Python install prefix unless it is a standard system prefix path
              if( PYTHON_LIBRARY AND PYTHON_PREFIX AND NOT CMAKE_SYSTEM_PREFIX_PATH MATCHES ${PYTHON_PREFIX} )
                set( PYTHON_LIBRARY "-L${PYTHON_PREFIX}/lib -Wl,-rpath,${PYTHON_PREFIX}/lib ${PYTHON_LIBRARY}" )
              endif()

              set( PYTHON_INCLUDE_DIR "${PYTHON_INCLUDE_DIR}" CACHE PATH
                   "Path to where Python.h is found" FORCE )
            endif()

            if(DEFINED PYTHON_INCLUDE_PATH AND NOT DEFINED PYTHON_INCLUDE_DIR)
              set( PYTHON_INCLUDE_DIR "${PYTHON_INCLUDE_PATH}" CACHE PATH
                   "Path to where Python.h is found" FORCE )
            elseif( NOT PYTHON_INCLUDE_DIR )
              execute_process(COMMAND "${PYTHON_CONFIG_EXECUTABLE}" --includes
                              OUTPUT_VARIABLE PYTHON_INCLUDE_DIR
                              OUTPUT_STRIP_TRAILING_WHITESPACE
                              ERROR_QUIET)

              string(REGEX REPLACE "^[-I]" "" PYTHON_INCLUDE_DIR "${PYTHON_INCLUDE_DIR}")
              string(REGEX REPLACE "[ ]-I" " " PYTHON_INCLUDE_DIR "${PYTHON_INCLUDE_DIR}")

              separate_arguments(PYTHON_INCLUDE_DIR)
              set( PYTHON_INCLUDE_DIR "${PYTHON_INCLUDE_DIR}" CACHE PATH
                   "Path to where Python.h is found" FORCE )

            endif()

            set(PYTHON_INCLUDE_DIRS "${PYTHON_INCLUDE_DIR}")
            set(PYTHON_LIBRARIES "${PYTHON_LIBRARY}")

            find_package_handle_standard_args( PythonLibs DEFAULT_MSG
                                               PYTHON_INCLUDE_DIRS PYTHON_LIBRARIES )

        else() # revert to finding pythonlibs the standard way (cmake macro)
            ecbuild_debug( "ecbuild_find_python: Searching for Python include directories and libraries using find_package( PythonLibs "${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}.${PYTHON_VERSION_PATCH}" ${_p_REQUIRED} )" )

            find_package( PythonLibs "${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}.${PYTHON_VERSION_PATCH}" ${_p_REQUIRED} )

        endif()

        # Remove duplicate include directories
        list(REMOVE_DUPLICATES PYTHON_INCLUDE_DIRS)


        if( PYTHON_LIBRARIES AND PYTHON_INCLUDE_DIRS )
            # Test if we can link against the Python libraries and include Python.h
            try_compile( PYTHON_LIBS_WORKING ${CMAKE_CURRENT_BINARY_DIR}
                         ${__test_python}
                         CMAKE_FLAGS "-DINCLUDE_DIRECTORIES=${PYTHON_INCLUDE_DIRS}"
                         LINK_LIBRARIES ${PYTHON_LIBRARIES}
                         OUTPUT_VARIABLE __try_compile_output )
            if( NOT PYTHON_LIBS_WORKING )
              ecbuild_debug( "ecbuild_find_python: trying to link executable with Python libraries failed\n${__try_compile_output}" )
            endif()

        endif()

    endif()

    find_package_handle_standard_args( Python DEFAULT_MSG ${__required_vars} )

    ecbuild_debug_var( PYTHONINTERP_FOUND )
    ecbuild_debug_var( PYTHON_FOUND )
    ecbuild_debug_var( PYTHON_EXECUTABLE )
    ecbuild_debug_var( PYTHON_CONFIG_EXECUTABLE )
    ecbuild_debug_var( PYTHON_VERSION_MAJOR )
    ecbuild_debug_var( PYTHON_VERSION_MINOR )
    ecbuild_debug_var( PYTHON_VERSION_PATCH )
    ecbuild_debug_var( PYTHON_VERSION_STRING )
    ecbuild_debug_var( PYTHON_INCLUDE_DIRS )
    ecbuild_debug_var( PYTHON_LIBRARIES )
    ecbuild_debug_var( PYTHON_SITE_PACKAGES )

    set( PYTHONINTERP_FOUND    ${PYTHONINTERP_FOUND} PARENT_SCOPE )
    set( PYTHONLIBS_FOUND      ${PYTHONLIBS_FOUND} PARENT_SCOPE )
    set( PYTHON_FOUND          ${PYTHON_FOUND} PARENT_SCOPE )
    set( PYTHON_EXECUTABLE     ${PYTHON_EXECUTABLE} PARENT_SCOPE )
    set( PYTHON_VERSION_MAJOR  ${PYTHON_VERSION_MAJOR} PARENT_SCOPE )
    set( PYTHON_VERSION_MINOR  ${PYTHON_VERSION_MINOR} PARENT_SCOPE )
    set( PYTHON_VERSION_PATCH  ${PYTHON_VERSION_PATCH} PARENT_SCOPE )
    set( PYTHON_VERSION_STRING ${PYTHON_VERSION_STRING} PARENT_SCOPE )
    set( PYTHON_INCLUDE_DIRS   ${PYTHON_INCLUDE_DIRS} PARENT_SCOPE )
    set( PYTHON_LIBRARIES      ${PYTHON_LIBRARIES} PARENT_SCOPE )
    set( PYTHON_SITE_PACKAGES  ${PYTHON_SITE_PACKAGES} PARENT_SCOPE )

endfunction( ecbuild_find_python )
