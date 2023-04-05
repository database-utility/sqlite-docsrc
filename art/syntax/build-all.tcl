#!/bin/tclsh
#
# This script does
# ----------------
#
#   1.  **omitted**
#
#   2.  **omitted**
#
#   3.  Scan all *.pikchr files and gather all child elements
#       Use this to construct syntax_linkage() array and the
#       syntax_order list in the "syntax_linkage.tcl" file
#
# More information about item 3
# -----------------------------
#
#    syntax_linkage($diagram) [list $child-diagram-list $parent-diagram-list]
#
# There is one syntax_linkage() entry for each diagram.  The value is a
# pair.  The first element of the pair is a list of all other diagrams
# that are children (that are referenced by) the current diagram.  The
# second element of the pair is a list of all other diagrams that reference
# the current diagrams.  Either list can be empty.
#
# The children of a diagram are determined by looking for entries of the
# form:
#
#       box "$child-name" fit
#
# The parent lists are constructed by inverting the child lists.
#
#    syntax_order $list-of-all-diagrams
#
# The syntax_order variable holds a list of all diagrams.  The order
# of the elements on the list determines the display order in the
# syntaxdiagrams.html page.
# 

cd [file dirname $argv0]
foreach pikchr [glob *.pikchr] {
  set base [file rootname $pikchr]
  set in [open $pikchr rb]
  set txt [read $in]
  close $in
  unset -nocomplain b
  foreach line [split $txt \n] {
    if {[regexp {box "(.*)" fit} $line all item] && $base!=$item} {
       set b($item) 1
    }
  }
  set children($base) [lsort [array names b]]
}
foreach base [array names children] {
  set parents($base) {}
}
foreach base [array names children] {
  foreach child $children($base) {
    if {[lsearch $parents($child) $base]<0} {
      lappend parents($child) $base
    }
  }
}
foreach base [array names children] {
  set parents($base) [lsort $parents($base)]
}
set out [open syntax_linkage.tcl wb]
foreach base [lsort [array names children]] {
  puts $out "set syntax_linkage($base)\
             [list [list $children($base) $parents($base)]]"
}
puts $out "set syntax_order [list [lsort [array names children]]]"
close $out
