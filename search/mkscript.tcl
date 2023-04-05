#!/usr/bin/tclsh
#
# Use this script to build the TCL scripts that implement the search
# functions on the SQLite website.
#
# Usage example:
#
#     tclsh mkscript.tcl search.tcl.in >search.tcl
#
# The input to this script is a template script file, named something
# like "search.tcl.in".  This script reads the template line-by-line and
# applies some minor transformations:
#
#     INCLUDE filename         Lines match this pattern are replaced
#                              by the complete text of filename.  This
#                              is used (for example) to insert the
#                              complete text of wapp.tcl in the appropriate
#                              place CGI scripts
#
#     DOCHEADER title path     Lines matching this pattern invoke the
#                              document_header function contained in the
#                              ../document_header.tcl file to generate
#                              header text for the document, and then
#                              insert that header text in place of the
#                              line
#
# Other than these transformations, the input is copied through into
# the output.
#
if {[llength $argv]!=1} {
  puts stderr "Usage: $argv0 TEMPLATE >OUTPUT"
  exit 1
}
set infile [lindex $argv 0]
set ROOT [file dir [file dir [file normalize $argv0]]]
set HOME [file dir [file normalize $infile]]
set in [open $infile rb]
while {1} {
  set line [gets $in]
  if {[eof $in]} break
  if {[regexp {^INCLUDE (.*)} $line all path]} {
    set in2 [open $HOME/$path rb]
    puts [read $in2]
    close $in2
    continue
  }
  if {[regexp {^DOCHEAD } $line] && [llength $line]==3} {
    source $ROOT/document_header.tcl
    puts [document_header [lindex $line 1] [lindex $line 2]]
    continue
  }
  puts $line
}
close $in
