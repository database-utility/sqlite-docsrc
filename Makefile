#!/usr/make
#

#####
# Documentation builds require Tcl librarys, version 8.6 or later.
# The TCLINC and TCLFLAGS macros are appropriate for the default Tcl
# development libraries on Ubuntu.  You may need to make adjustments.
#
TCLINC = -I/usr/include/tcl8.6
TCLFLAGS = -L/usr/lib/x86_64-linux-gnu -ltcl8.6 -ldl -lm -lpthread -lz

# Alternative TCL settings:
#
#TCLINC = -I$(HOME)/tcl/include
#TCLFLAGS = -static $(HOME)/tcl/lib/libtcl8.6.a -ldl -lm -lpthread -lz
#
#TCLINC = -I$(HOME)/tcl/include
#TCLFLAGS = -L$(HOME)/lib -ltcl8.7 -ldl -lm -lpthread -lz
#
# The altenative settings will work if you build your on TCL as follows:
#
#     # unpack the tarball (tcl 8.6 or later)
#     cd unix
#     ./configure --prefix=$(HOME)/tcl
#     make install
#
# That will install the necessary tcl libraries in $(HOME)/tcl.
####


#### The toplevel directory of the documentation source.
#    Change to something different if building out-of-tree
#
DOC = .

#### The toplevel directory of the program source code.
#
SRC = ../sqlite

#### The directory in which has been run "make sqlite3.c" for the
#    SQLite source code.  The documentation generator scripts look
#    for files "sqlite3.h", "tclsqlite3.c" and "sqltclsh" in this
#    directory.
#    Set up the SQLite build using:
#
#         cd $(BLD)
#         $(SRC)/configure
#         make tclsqlite3.c sqltclsh
#
BLD = ../sqlite

#### The toplevel directory of the TH3 test harness sources
#    Leave blank if TH3 is not available.
#
TH3 = 

#### The toplevel directory of the SQLLogicTest (SLT) test
#    harness sources.  Leave blank if SLT is not available.
#
SLT = 

#### A C-compiler for building utility programs to run locally
#
CC = gcc -g -Wall -I$(BLD)

# You should not have to change anything below this line
###############################################################################
include $(DOC)/main.mk
