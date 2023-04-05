set usage {
Usage:
  append_db [page_size_opt] <appendee_filename> <sdb_filename> <out_filename>
If provided, page_size_opt must be --page-size <log2_of_page-size> ,
defaulting to 12 (for a page-size of 1 << 12 = 4096.)

The named appendee file will be padded to a multiple of the page-size, then
appended with the named SQLite database file, end-marked as described by
  https://sqlite.org/src/file?name=ext/misc/appendvfs.c&ci=trunk
, to produce the named out file. This file can be used by applications that
use the appendvfs to locate and open a SQLite database so appended to the
end of their executable image. The padding to a page size boundary improves
SQLite's performance when accessing the database, provided that the page
size used is an integer multiple of the storage device's block size.
}

if {[llength $argv] >= 2 && [lindex $argv 0] eq "--page-size"} {
  set ln2ps [lindex $argv 1]
  set argv [lreplace $argv 0 1]
  if {![regexp {^\d{1,2}$} $ln2ps]} {
    puts stderr "Page size argument must be a positive integer, (not $ln2ps)."
    puts stderr $usage
    exit 1
  }
  set pageSize [expr 1 << $ln2ps]
} else {
  set pageSize 4096
}

proc moanQuit {why} {
  puts stderr $why
  exit 1
}

if {[llength $argv] < 3} {
  moanQuit $usage
}

foreach {afn sdb ofn} $argv break

if {[file isdirectory $ofn]} {
  moanQuit "Will not write directory $ofn ."
}
if {![file isfile $afn] || ![file readable $afn]} {
  moanQuit "Cannot read $afn as a plain file."
}
if {[catch {set sfd [open $sdb rb]}]} {
  moanQuit "Cannot read alleged DB, $sdb"
}
if {[read $sfd 15] ne "SQLite format 3"} {
  close $sfd
  moanQuit "$sdb is not a SQLite3 database."
}
if {[catch {file copy -force -- $afn $ofn}]} {
  close $sfd
  moanQuit "Cannot copy $afn to $ofn."
}

if {[catch {set ofd [open $ofn ab]}]} {
  close $sfd
  moanQuit "Cannot append $ofn"
}
set appendeeLen [file size $afn]
set pageFrac [expr $appendeeLen % $pageSize]
set padCount [expr ($pageFrac > 0)? $pageSize - $pageFrac : 0]
set sdbOffset [expr $appendeeLen + $padCount]

while {$padCount >= 1024} {
  puts -nonewline $ofd [string repeat "        " 128]
  set padCount [expr $padCount - 1024]
}
if {$padCount > 0} {
  puts -nonewline $ofd [string repeat " " $padCount]
}
seek $sfd 0
fcopy $sfd $ofd
seek $sfd -25 end
set appVfsMark "Start-Of-SQLite3-"
if {[read $sfd 17] ne $appVfsMark} {
  # Looks like an ordinary DB, convert to appendvfs.
  puts -nonewline $ofd $appVfsMark
} else {
  seek $ofd -8
}
close $sfd
# Out file about to have or already has an appendvfs DB mark, set its offset.
puts -nonewline $ofd [binary format "W" $sdbOffset]
close $ofd
