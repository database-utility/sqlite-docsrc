#!/usr/bin/tclsh
set usage {Usage:
  hlinkch.tcl <doc_root> <hldb> <html_pages>
}

if {$argc >= 2 && [lindex $argv 0] eq "--url-normalize-log"} {
  set ::iun [open [lindex $argv 1] w]
  incr argc -2
  set $argv [lrange $argv 2 end]
} else { set ::iun "" }

if {$argc < 3} { puts $usage; exit 0 }

set ::doc_root_nom [lindex $argv 0]
set ::drre "^$::doc_root_nom/"
set ::doc_root [file normalize $::doc_root_nom]
set ::doc_rlen [expr [string length $::doc_root] + 1]
set hlink_db [lindex $argv 1]
set argv [lrange $argv 2 end]
incr argc -2
set sdir [file dirname [info script]]
source [file join $sdir search hdom.tcl]

# Normalize input filename to be docroot-relative.
proc finorm {fn} {
  regsub $::drre $fn {} fn
  set fn [file normalize $fn]
  set drix [string first $::doc_root $fn]
  if {$drix != 0} { return $fn }
  return [string range $fn $::doc_rlen end]
}

# Normalize internal URL filename to be docroot-relative.
# Inputs are relative to the source referencing the URL.
# Directories . or .. must be leading for this to work.
proc iunorm {ufn sfn} {
  set rv $ufn
  set sdir [file dirname $sfn]
  if {$sdir eq "."} { set sds [list] } else { set sds [file split $sdir] }
  if {[regexp {^(\.\.?)/(.*)} $ufn _ dd ufnnd]} {
    switch $dd {
      . { set rv [file join {*}$sds $ufnnd] }
      .. {
        set rv [file join {*}[lrange $sds 0 end-1] $ufnnd]
      }
    }
  } else {
    set rv [file join {*}$sds $ufn]
  }
  if {$::iun ne ""} { puts $::iun "$ufn|$sfn|$rv" }
  return $rv
}

set owd [pwd]
cd $::doc_root
set inhtml [lmap f $argv {finorm $f}]

package require sqlite3

try {
  sqlite3 db :memory:
  db eval {
    CREATE TABLE IF NOT EXISTS LinkDefs(
     url TEXT, frag TEXT,
     UNIQUE(url, frag) ON CONFLICT IGNORE
    );
    CREATE TABLE IF NOT EXISTS IntLinkRefs(
     url TEXT, frag TEXT, fsrc TEXT,
     UNIQUE(url, frag, fsrc) ON CONFLICT IGNORE
    );
    CREATE TABLE IF NOT EXISTS ExtLinkRefs(
     url TEXT, frag TEXT, fsrc TEXT,
     UNIQUE(url, frag, fsrc) ON CONFLICT IGNORE
    );
    CREATE VIEW IF NOT EXISTS BrokenPageLinks AS
    SELECT r.url || iif(r.frag <> '', '#'||r.frag, '') AS url, r.fsrc as fsrc
    FROM IntLinkRefs r LEFT JOIN LinkDefs d USING(url)
    WHERE d.url IS NULL
    ;
    CREATE VIEW IF NOT EXISTS BrokenFragLinks AS
    SELECT r.url || iif(r.frag <> '', '#'||r.frag, '') AS url, r.fsrc as fsrc
    FROM IntLinkRefs r LEFT JOIN LinkDefs d USING(url,frag)
    WHERE d.url IS NULL AND r.fsrc NOT IN ('vdbe.html')
    ;
    CREATE VIEW IF NOT EXISTS ExtHttpLinks AS
    SELECT DISTINCT url FROM ExtLinkRefs WHERE url LIKE 'http%'
    AND url NOT LIKE 'https://www.sqlite.org/src/%'
    AND url NOT LIKE 'https://sqlite.org/src/%'
    AND url NOT LIKE 'http://www.sqlite.org/src/%'
    AND url NOT LIKE 'http://sqlite.org/src/%'
    AND url NOT LIKE 'https://www.fossil-scm.org/fossil/artifact/%'
    AND url NOT LIKE 'https://sqlite.org/forum/forumpost/%'
    ;
  }
} on error sle {
  puts stderr "Error with DB: $sle"
  exit 1
}

proc add_ref {u f s} {
  try {
    set u [iunorm $u $s]
    db eval {
      INSERT INTO IntLinkRefs(url, frag, fsrc)
      VALUES($u, $f, $s)
    }
  } on error db_conflict {
  }
}

proc add_ext {u f s} {
  try {
    db eval {
      INSERT INTO ExtLinkRefs(url, frag, fsrc)
      VALUES($u, $f, $s)
    }
  } on error db_conflict {
  }
}

proc add_def {u f s} {
  try {
    set u [iunorm $u $s]
    db eval {
      INSERT INTO LinkDefs(url, frag)
      VALUES($u, $f)
    }
  } on error db_conflict {
  }
}

if {[info command parsehtml] ne "parsehtml"} {
  try {
    load [file join $owd search parsehtml.so]
  } on error erc {
    puts stderr "Error: Could not load parsehtml DLL ($erc)"
    exit 1
  }
}

db eval {BEGIN TRANSACTION}
puts -nonewline "\
Scanning [llength $inhtml] files for hyperlink defs and refs, working on #"
set nscanning 0
set nsay ""

set ext_url_re {^((?:https?://)|(?:ftp://)|(?:mailto:))([^#]+)(#.*)?}

foreach html_src $inhtml {
  set html_dir [file dirname $html_src]
  try {
    set rpfid [open $html_src r]
    set nbu [string length $nsay]
    set nsay [format "%d" [incr nscanning]]
    puts -nonewline "[string repeat \b $nbu]$nsay"
    flush stdout
  } on error erc {
    puts stderr "Error: $erc"
    exit 1
  }
  set doc [hdom parse [read $rpfid]]
  close $rpfid

  set src_basename [file tail $html_src]
  add_def $src_basename "" $html_src

  set rn [$doc root]

  $rn foreach_descendent dnode {
    set tag [$dnode tag]
    # Certain elements define fragment labels with their 'id' attribute.
    regsub {^(h[1-6])|(dt)$} $tag idt tag
    switch $tag {
      a {
        foreach {an av} [$dnode attr] {
          if {$an eq "name"} {
            add_def $src_basename $av $html_src
            continue
          } elseif {$an ne "href"} continue
          if {[regexp $ext_url_re $av _ transport loc at]} {
            add_ext "${transport}${loc}" $at $html_src
          } else {
            if {[regexp {^javascript:} $av]} continue
            if {![regexp {^([^#]*)#(.*)$} $av _ av at]} {
              set at ""
            } elseif {$av eq ""} {
              set av $html_src
            }
            add_ref $av $at $html_src
          }
        }
      }
      idt {
        foreach {an av} [$dnode attr] {
          if {$an eq "id"} {
            add_def $src_basename $av $html_src
            break
          }
        }
      }
    }
  }
  $doc destroy
}
db eval {COMMIT TRANSACTION}

cd $owd
puts "\nWriting $hlink_db"
file delete -force $hlink_db
db eval { VACUUM INTO $hlink_db }

db close
if {$::iun ne ""} { close $::iun }
