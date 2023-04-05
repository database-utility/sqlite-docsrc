## SQLite Documentation

This repository contains scripts used to generate the documentation
for [SQLite](https://www.sqlite.org/).  This repository also contains
much of the content of the documentation, though some of the content
is extracted from special comments in the SQLite sources and in the
[TH3](https://www.sqlite.org/th3.html) sources and in the
[SQL Logic Test](https://www.sqlite.org/slt) sources.

The repository also contains the source code to the custom web server
that is used to run the SQLite website.  See
[](https://sqlite.org/althttpd) for additional information.

# How To Build

These are the steps to build the documentation:

  1.  Download and unpack the source trees for SQLite, TH3, and
      SQL Logic Test into sibling directories.  The SQLite install
      should be in ../sqlite.  TH3 should go into ../th3.  SQL Logic
      Test should go into ../sqllogictest.  The TH3 and SQL Logic Test
      installs are optional and are only used for requirements test coverage
      tracking.

  2.  Make sure you have TCL development libraries version 8.6 or later
      installed on your machine.

  3.  Edit the Makefile for your system.  Pay particular attention to:
      <ol type="a">
      <li><p> TCLINC= and TCLFLAGS= should point to the Tcl 8.6 development
          libraries.
      <li><p> Set TH3= and SLT= to empty strings if those
          source trees are not available to you.
      </ol>

  4.  Setup a SQLite library checkout which has been made ready to build
      and can be referenced as ../sqlite from the docsrc checkout root
      directory. These steps will suffice: <ol type="a">
      <li><p> pushd ../sqlite
      <li><p> ./configure
      <li><p> make tclsqlite3.c
      <li><p> popd
      </ol>

  5.  Run:  "make all"

The documentation will be built into the docs/ subdirectory.
