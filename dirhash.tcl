#!./tclsh.docsrc
#
# A tool for determining what files in a directory have changed content.
# A SQLite DB in the specified directory, dirhash.db, aids this.

set usage {Usage:
  hashdir [<option>] <dirPath> [<globPatternFile> ...]

This program will consult a SQLite database, at <dirPath>/dirhash.db,
to determine and report which files of those specified have changed,
appeared or vanished since hashdir was last run on the same directory.

With <option> -update, that database is updated after the report to
reflect the current state of the specified files. Or, <option> -acquire
will supress the report and so update the database.

The <globPatternFile> arguments are of two kinds: Those containing a '*'
which specify a set of files to possibly be found in the <dirPath>; and
those without any '*' which specify a file whether it is there or not.
Each <globPatternFile> spec is interpreted as relative to the <dirPath>.

With one or more <globPatternFile> arguments, only the specified files
will be compared or tracked. Otherwise, all files in directory <dirPath>
will be, except for the dirhash.db database file itself.
}
#

set update 0
if {$argc > 0 && [string index [lindex $argv 0] 0] eq "-"} {
  set option [lindex $argv 0]
  set argv [lrange $argv 1 end]
  incr argc -1
  switch $option {
    -update {set update 1}
    -acquire {set update 2}
    default {
      puts $usage
      exit 1
    }
  }
}

if {$argc < 1} {
  puts $usage
  exit 0
}
set dir_path [lindex $argv 0]
# A special undocumented feature: @ is the script directory.
regsub {^@} $dir_path [file dirname [info script]] dir_path
set dir_path [file normalize $dir_path]
if {$argc > 1} {
  set globfs [lrange $argv 1 end]
} else { set globfs [list *] }

set dbfname dirhash.db

set fspecs [list]

set dirold [pwd]
cd $dir_path

array set fsdedupe [list $dbfname 1] ;# Pretend DB file already seen.

foreach fs $globfs {
  if {[string last * $fs] < 0} {
    if {[file isfile $fs]} {
      lappend fspecs $fs
    } else { puts stderr "Not a normal file: $fs" }
  } else {
    set fst [glob $fs]
    if {[llength $fst] == 0} {
      puts stderr "Matches nothing: $fs"
      continue
    }
    foreach ft $fst {
      if {[incr fsdedupe($ft)] == 1} {
        if {[file isfile $ft]} {
          lappend fspecs $ft
        }
      }
    }
  }
}

sqlite3 db $dbfname
db function file_hash -argcount 1 -directonly md5file

db eval {
  CREATE TABLE IF NOT EXISTS DirHad( fname TEXT, hash TEXT );
  CREATE TEMP TABLE FnameLook( fname TEXT, hash TEXT );
  BEGIN
}

foreach fn $fspecs {
  db eval {INSERT INTO FnameLook VALUES($fn, file_hash($fn))}
}
db eval {COMMIT}

db eval {
  CREATE TEMP VIEW new AS
  SELECT n.fname AS fname FROM FnameLook n LEFT JOIN DirHad o USING (fname)
  WHERE o.fname IS NULL ORDER by fname;

  CREATE TEMP VIEW zap AS
  SELECT o.fname AS fname FROM DirHad o LEFT JOIN FnameLook fl USING (fname)
  WHERE fl.fname IS NULL ORDER by fname;

  CREATE TEMP TABLE chg AS
  SELECT o.fname AS fname FROM DirHad o INNER JOIN FnameLook fl USING (fname)
  WHERE fl.hash<>o.hash ORDER BY fname
}

set ::newfiles [db eval {SELECT fname FROM new}]
set ::zapfiles [db eval {SELECT fname FROM zap}]
set ::chgfiles [db eval {SELECT fname FROM chg}]

proc saydiff {flist what sep} {
  if {[llength $flist] > 0} {puts "$what files:$sep[join $flist $sep]"}
}
if {$update < 2} {
  saydiff $::newfiles New " "
  saydiff $::zapfiles Gone " "
  saydiff $::chgfiles Changed "\n"
}

if {$update > 0} {
  db eval {
    DELETE FROM DirHad WHERE fname IN (SELECT fname FROM zap);
  }
  db eval {
    INSERT INTO DirHad SELECT fname, hash FROM FnameLook
    WHERE fname IN (SELECT fname from new);
  }
  db eval {
    UPDATE DirHad AS h SET hash=fl.hash
    FROM (SELECT fname, hash FROM FnameLook) fl
    WHERE h.fname=fl.fname AND h.fname IN (SELECT fname from chg)
  }
}
