#!/usr/bin/tclsh
#
# Usage:
#
#   tclsh remove_carets.tcl [-at <pathnames_file>] <glob patterns>
#
# This script scans all specified files and removes certain
# character sequences from them. The files specified are
# those glob-matching the given <glob patterns> and those
# named, one per line, in the <pathnames_file> (if any.)
# Character sequences removed are:
#
#     ^(
#     )^
#     ^
#
if {$argc < 1} {
  puts stderr "Removing no ^ characters."
  exit 1
}
if {[lindex $argv 0] eq "-v"} {
  set sayStats 1
  set argv [lreplace $argv 0 0]
  incr argc -1
} else {set sayStats 0}

if {[lindex $argv 0] eq "-at"} {
  if {$argc < 2} {
    puts stderr "Bad remove_carets invoke."
    exit 1
  }
  set fnfd [open [lindex $argv 1] r]
  set flist [split [read $fnfd] "\n"]
  close $fnfd
  set files [lreplace $flist end end]
  set fla 2
} else {
  set files [list]
  set fla 0
}
foreach fgspec [lrange $argv $fla end] {
  lappend files {*}[glob $fgspec]
}

set fcount 0
set rcount 0
array set fstats {}
set killPattern {(\^\()|(\)\^)|\^}
if {!$sayStats} {puts -nonewline {Removing ^( )^ and ^ ...}}
foreach fm $files {
  if {![info exists fstats($fm)]} {
    set ifd [open $fm r]
    set text [regsub -all $killPattern [read $ifd] {}]
    set shrink [expr [file size $fm] - [string length $text]]
    set fstats($fm) $shrink
    close $ifd
    incr fcount
    if {$shrink > 0 && !$sayStats} {
      set ofd [open $fm w]
      puts -nonewline $ofd $text
      close $ofd
      incr rcount
    }
  }
}

if {$sayStats} {
  foreach fm [array names fstats] {
    puts "$fm,$fstats($fm)"
  }
} else {puts "\b\b\bfrom $rcount of $fcount files."}
