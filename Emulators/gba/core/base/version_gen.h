// -*- C++ -*-
// VisualBoyAdvance-m - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2004 Forgotten and the VBA development team

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or(at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#ifndef VBAM_CORE_BASE_VERSION_GEN_H_
#define VBAM_CORE_BASE_VERSION_GEN_H_

#define VBAM_NAME "VisualBoyAdvance-M"
#define VBAM_CURRENT_VERSION "2.1.11"

#define VBAM_FEATURE_STRING ""

#define _STRINGIFY(N) #N

#if 1
    #define VBAM_SUBVERSION_STRING ""
#else
    #define VBAM_SUBVERSION_STRING "-" ""
#endif

#if defined(_MSC_VER)
    #define VBAM_COMPILER "msvc"
    #define VBAM_COMPILER_DETAIL _STRINGIFY(_MSC_VER)
#else
    #define VBAM_COMPILER ""
    #define VBAM_COMPILER_DETAIL ""
#endif

#define VBAM_VERSION_STRING      VBAM_CURRENT_VERSION VBAM_SUBVERSION_STRING VBAM_FEATURE_STRING VBAM_COMPILER
#define VBAM_NAME_AND_VERSION    VBAM_NAME " " VBAM_VERSION_STRING
#define VBAM_NAME_AND_SUBVERSION VBAM_NAME_AND_VERSION VBAM_SUBVERSION_STRING

#define VBAM_VERSION VBAM_CURRENT_VERSION VBAM_SUBVERSION_STRING

#define VER_FILEVERSION_STR VBAM_VERSION
#define VER_FILEVERSION 2,1,11,0

#endif  /* VBAM_CORE_BASE_VERSION_GEN_H_ */
