#!./tclsh.docsrc
#
# A tool for updating the SQLite version info list embedded in
# pages/chronology.tcl using data taken from a Fossil repo.

set usage {
Usage:
  ./regen_version_list [<sqlite_repo.fossil>]
 where the argument names a Fossil repository in which SQLite source
 versions are kept. Provided the repository appears to be valid and
 holds version info already embedded within $DOC/pages/chronology.tcl,
 a successful run will modify that file in place to reflect the most
 current release(s) also.

 The repository argument is optional if the directory ../sqlite
 exists and is a Fossil check-out directory for the SQLite library.

 A failed run will report why and exit with an error status.

 On success, the number of versions added is reported. If that is
 greater than 0, a reminder to check-in the modified chronology.tcl
 is issued. Otherwise, the file's mtime timestamp is left unchanged.
}

# Run from root of docsrc checkout (where this script is.)
cd [file dir [info script]]

if {$argc < 1} {
  # Attempt to locate SQLite library repo through ../sqlite check-out.
  set owd [pwd]
  if {[file isdirectory ../sqlite] && ![catch {cd ../sqlite}]} {
    if {![catch {set fost [exec fossil status]}]} {
      foreach {fsline} [split $fost "\n"] {
        if {[regexp {^repository: *([^ ].*)$} $fsline _ repo]} break
      }
    }
    cd $owd
    if {[info exists repo]} { set argv [list $repo]; set argc 1 }
  }
}

if {$argc < 1} {
  puts stderr $usage
  exit 1
}
set repo [lindex $argv 0]
if {[catch {sqlite3 rdb -create 0 $repo} yap]} {
  puts stderr "Error: Repo DB, \"$repo\", could not be opened: $yap"
  exit 1
}
set isrepo [rdb onecolumn {
  SELECT count(name)=4 FROM sqlite_schema
  WHERE type='table' AND name IN ('blob','event','delta','filename')
}]
if {!$isrepo} {
  puts stderr "Error: \"$repo\" is not a Fossil repo DB file."
  rdb close
  exit 1
}

set ::revs_count 0
set ct [file dirname [info script]]/pages/chronology.tcl

set tv {
  CREATE VIEW temp.Versions AS
  SELECT
    (SELECT substr(uuid,1,10) FROM blob WHERE rid=objid) AS ht,
    datetime(mtime) AS tstamp, date(mtime) AS day,
    rtrim(trim(coalesce(ecomment,comment)),'.') AS comment
  FROM event
  WHERE coalesce(ecomment,comment) glob 'Version [123].*'
  ORDER BY tstamp DESC;
}
set vq {
  SELECT ht ||'|'|| day  ||'|'|| comment AS ver FROM temp.Versions
  WHERE comment NOT LIKE '%prerelease%' AND comment NOT LIKE '%patches%'
  AND comment NOT LIKE '%andidate%' AND comment NOT LIKE '%withdrawn%'
  AND ht NOT IN ('dde65e9e06','d07b7b67d1','972e75bb5d','917c410808',
  '605907e73a','f139f6f07d','1df5386a55','765359c77e','8467d84fc6',
  '0a8c2f4f98','003f967e87','b0805b6069') -- de-duplication clause
  ORDER BY tstamp DESC;
}

set ::versions_now [list]
set exit_status 0
try {
  rdb eval $tv
  set ::versions_now [rdb eval $vq]
} on error erc {
  puts stderr "View creation or versions query failed."
  set exit_status 1
} finally {
  rdb close
}

if {$exit_status > 0} {exit $exit_status}

set lines_before [list]
array set ::versions_pending [list]
set versions_old [list]
set lines_after [list]
set glom_state 0
set glomee lines_before

set ::versionRe {^[0-9a-f]{10}\|}
set ::pendingRe {^x{6,10}\|[^\|]*\|}
set ::verNumRe {([0-9\.]+) *$}

proc add_pending {line} {
  set vtag [regsub -nocase $::pendingRe $line {}]
  if {![regexp $::verNumRe $vtag _ vn]} {
    puts stderr "Cannot extract version number from: $line"
    exit 1
  }
  incr ::versions_pending($vn)
}

try {
  set ct_fid [open $ct r]
  while {![eof $ct_fid]} {
    if {[gets $ct_fid line] < 0} break
    if {[set line [string trimright $line]] ne ""} {
      set isvl [regexp $::versionRe $line]
      set isvp [regexp -nocase $::pendingRe $line]
      switch $glom_state {
        0 {
          if {$isvp} {add_pending $line; continue}
          if {$isvl} {incr glom_state; set glomee versions_old}
        }
        1 { if {!$isvl} {incr glom_state; set glomee lines_after} }
        2 {}
      }
    }
    lappend $glomee $line
  }
  close $ct_fid
} on error orc {
  puts stderr "Error: Cannot read $ct ."
  exit 1
}
set ::noldver [llength $versions_old]
set ::nnewver [llength $::versions_now]

if {$::nnewver < $::noldver} {
  puts stderr "Error: Versions list is shrinking. No update done."
  exit 1
}

# Do a sanity check on prior or all versions.
for {set io $::noldver; set in $::nnewver} {$io > 0 && $in > 0} {} {
  incr io -1; incr in -1
  if {[lindex $versions_old $io] ne [lindex $::versions_now $in]} {
    puts stderr "Error: Version history appears to be changing. Aborting."
    exit 1
  }
}
set ::revs_count [expr $::nnewver - $::noldver]

proc resolve_pending_new {} {
  set rv [list]
  set ixo [llength $::versions_now]
  for {set ix 0} {$ix < $::revs_count} {incr ix} {
    set vnew [lindex $::versions_now [expr $ix + $::noldver]]
    if {[regexp $::verNumRe $vnew _ vn]} {
      unset -nocomplain $::versions_pending($vn);
    }
  }
  set pvs [lsort [array names ::versions_pending]]
  foreach vn $pvs {
    lappend rv "xxxxxxxxxx|pending|Version $vn"
  }
  if {[array size ::versions_pending] > 0} {
    puts stderr "Still-pending versions: [join $pvs { }]"
  }
  return $rv;
}

if {$::revs_count > 0} {
  if {[array size ::versions_pending] > 0} {
    set vp_left [resolve_pending_new]
  } else { set vp_left [list] }
  try {
    set ct_fid [open $ct w]
    puts $ct_fid [join $lines_before "\n"]
    if {[llength $vp_left] > 0} {
      puts $ct_fid [join $vp_left "\n"]
    }
    puts $ct_fid [join $::versions_now "\n"]
    puts $ct_fid [join $lines_after "\n"]
  } on error owc {
    puts stderr "Error: Cannot write $ct with new version(s). Aborting."
    exit 1
  }
  close $ct_fid
  set post_msg "Source-controlled file \"$ct\" should be checked in."
} else {
  set post_msg "Source-controlled file \"$ct\" was not modified."
}
puts "Number of revisions added to \"$ct\": $::revs_count"
puts $post_msg
exit 0
