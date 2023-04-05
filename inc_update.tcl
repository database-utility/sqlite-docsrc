# This source provides Tcl procs which aid efficient, incremental
# generation of SQLite HTML docs from their sources.
#
# The generation is done by wrap.tcl, but with use of these procs,
# only pages/*.in files which have been modified since the prior
# generation are scanned for link references and translated into
# doc/*.html output. This typically reduces doc update time to
# under 1% of the time needed to process all of the input files.
#
# These procs rely on a DB, docinfo.db, as created by schema.tcl .
#
################ These procs are provided:
#
# Note that in these notes, "didb" is the name of the DB opened
# by wrap.tcl to retain various data after and across doc builds.
# There is no useful return except as specifically documented.
# The procs are listed in typical usage order.
#
# temp_links_setup didb
#   Create transient tables necessary for operation of below procs.
#
# full_build_clear didb
#   Clear tables useful only for incremental builds. Use for full builds
#   to ensure that incremental builds rely on no stale link info.
#
# outdated_uptodate didb filelist
#   Partition an input filename list into two sets:
#   Set 1: files which are outdated or new with respect to prior doc gen.
#   Set 2: files which appear to be unchanged since the prior doc gen.
#   Return list of 2 lists, which contain set 1 and set 2 in that order.
#   The algorithm is not infallible. It will put a file into set 2 if
#   its modification time is earlier than when last processed and it
#   still has the same size. (This is a pathological case.) Otherwise,
#   files are put in set 1 if their size changes or (their modification
#   time becomes later and their md5 hash changes).
#
# fetch_links didb filelist
#   Fetch links associated with given files during previous doc gen
#   run and a count of global link references made from those files.
#   Return 4 lists ordered thus: GLOBAL, LOCAL, BACK, PAGE; and the
#   count. List elements are key value pairs, suitable for array set.
#
# note_source didb fname hash
#   Record input source file and its md5 hash for update detection.
#
# kidof_source didb fname
#   Return persisted id of an input file present in pages_in.
#   Only fname values known to be uptodate should be passed in.
#
# tidof_source didb fname
#   Return transient id of an input file to pass into next proc.
#   Only fname values given to outdated_uptodate should be passed in.
#
# note_link didb tag target kind tsid
#   Record a global, local, back- or page- link, or a global link
#   reference, for use in later incremental builds.
#   - tag is the key value used with ::{g,l,back,page}link arrays.
#   - target is the value kept for tag in one of those arrays.
#   - kind is 1 of GLOBAL LOCAL BACK PAGE GLREF for link/ref kind.
#   - tsid is the source Id obtained from tidof_source ... .
#
# unsatisfied_links didb
#   Determine which of the global link references (if any) are not
#   resolved by a link definition. This check is done near the end
#   of incremental build processing, after pass 2. At that point,
#   all link definitions should either have been added via note_link
#   or already exist among the global links for uptodate sources.
#   Returns a possibly empty list of unsatisfied tag refs pairs,
#   suitable for use with array set. The tag keys are unsatisfied
#   link tags and the refs values are lists of input file in which
#   the unsatisfied reference occurs.
#
# keep_links_fileinfo didb
#   Until this proc is run, data recorded by note_source and note_link
#   are transient and will vanish when the DB is closed. This proc
#   should be called upon successful build completion to move that
#   data to persistent tables of the DB for later incremental builds.
#   Note that this does not run COMMIT for the DB.
#
# report_inc_stats didb
#   Used for post-run reports of link gathering and retrieval.
#
################

# These constants are used by clients of this code and saved in a DB.
array set ::lk {
  GLOBAL 0 LOCAL 1 BACK 2 PAGE 3 GLREF 4
  0 GLOBAL 1 LOCAL 2 BACK 3 PAGE 4 GLREF
}

# For diagnostic logging only.
proc tid_to_fname {tid} {
  global tid2fname
  return $tid2fname($tid)
}

# Log link gathering and recreation into a named DB if certain env-var is set.
if {[info exists ::env(DOC_BUILD_LINKLOG)]} {
  set ::doc_build_linklog $::env(DOC_BUILD_LINKLOG)
  sqlite3 lldb :memory:
  lldb eval {BEGIN;
    CREATE TABLE lsl -- Link Set Log
    (eid INTEGER PRIMARY KEY, tag TEXT, target TEXT, kind TEXT, src);
    CREATE TABLE lfl -- Link Fetch Log
    (eid INTEGER PRIMARY KEY, tag TEXT, target TEXT, kind TEXT, src)
  }
  lldb function tid2fname -argcount 1 tid_to_fname

} else { set ::doc_build_linklog "" }

# Purely local functions for use in appending to {back,page}link lists.
# To avoid loss of listness, lists are tab-separated in the DB, and
# split on tab upon retrieval to recreate the backlink lists.
# On retrieval, they are also sorted with duplicates removed.
proc tsv_list_append {appendee appended} {
  return "$appendee\t$appended"
}
proc tsv_dedupe_norm {tsv} {
  return [join [lsort -unique [split $tsv "\t"]] "\t"]
}

proc temp_links_setup {didb} {
  set dis [$didb eval {
    SELECT count(*) FROM pragma_database_list WHERE name='mem'
  }]
  if {[info exists ::env(DOC_BUILD_TEMPDB)]} {
    set staging_db $::env(DOC_BUILD_TEMPDB)
  } else { set staging_db :memory: }
  if {!$dis} {
    $didb config trusted_schema 0
    $didb function file_hash -argcount 1 -directonly md5file
    $didb function tlist_append -argcount 2 tsv_list_append
    $didb function tsv_dedupe_norm -argcount 1 tsv_dedupe_norm
    $didb config trusted_schema 1
    $didb eval {
      ATTACH $staging_db AS mem;
      CREATE TABLE mem.disk_sources(fname TEXT UNIQUE, length INT,
                                    mtime INT, outdated INT);
      CREATE TABLE mem.link_sources(id INTEGER PRIMARY KEY,
                                    fname TEXT UNIQUE, length INT,
                                    mtime INT, hash TEXT);
      CREATE TABLE mem.links(tag TEXT,
                             target TEXT,
                             kind INT,
                             fid INT REFERENCES link_sources(id),
                             UNIQUE(tag,fid,kind) ON CONFLICT REPLACE);
      -- global link defs
      CREATE TEMP VIEW IF NOT EXISTS LinkDefs AS
      SELECT ds.fname AS fn, l.tag AS tag
      FROM mem.disk_sources ds JOIN mem.links l ON ds.fname=ls.fname
      JOIN mem.link_sources ls ON ls.id=l.fid
      WHERE ds.outdated AND l.kind=0
      UNION ALL
      SELECT pi.file_name AS fn, sl.tag AS tag
      FROM mem.disk_sources ds JOIN pages_in pi ON ds.fname=pi.file_name
      JOIN scan_links sl ON sl.fileid=pi.fileid
      WHERE NOT ds.outdated AND sl.kind=0;
      -- global link refs
      CREATE TEMP VIEW IF NOT EXISTS LinkRefs AS
      SELECT pi.file_name AS fn, sl.tag AS tag
      FROM mem.disk_sources ds JOIN pages_in pi ON ds.fname=pi.file_name
      JOIN scan_links sl ON sl.fileid=pi.fileid
      WHERE NOT ds.outdated AND sl.kind=4
      UNION ALL
      SELECT ds.fname AS fn, l.tag AS tag
      FROM mem.disk_sources ds JOIN mem.links l ON ds.fname=ls.fname
      JOIN mem.link_sources ls ON ls.id=l.fid
      WHERE ds.outdated AND l.kind=0;

      PRAGMA foreign_keys=1;
    }
    return 1
  } else {return 0}
}

proc note_source {didb fname hash} {
  file lstat $fname fattr
  set fsz $fattr(size)
  set mt $fattr(mtime)
  $didb eval {
    INSERT INTO mem.link_sources(fname, length, mtime, hash)
    VALUES($fname,$fsz, $mt, $hash)
  }
  return [$didb eval {SELECT last_insert_rowid()}]
}

proc tidof_source {didb fname} {
  return [$didb eval {
    SELECT id FROM mem.link_sources WHERE fname=$fname
  }]
}

# Internal proc to get persisted source file id.
# It will return {} if an outdated file is passed.
proc kidof_source {didb fname} {
  if {[$didb exists {
    SELECT outdated FROM mem.disk_sources WHERE fname=$fname AND outdated=0
  }]} {
    return [$didb eval {
      SELECT fileid FROM pages_in WHERE file_name=$fname
    }]
  } else {return {}}
}

set ::global_link_count_s 0
set ::local_link_count_s 0
set ::back_link_count_s 0
set ::page_link_count_s 0
set ::global_link_count_f 0
set ::local_link_count_f 0
set ::back_link_count_f 0
set ::page_link_count_f 0

proc note_link {didb tag target kind tsid} {
  set lki $::lk($kind)
  if {$::doc_build_linklog ne ""} {
    lldb eval {
      INSERT INTO lsl(tag,target,kind,src) VALUES($tag,$target,$kind,$tsid)
    }
  }
  if {$kind eq "GLOBAL" || $kind eq "LOCAL"} {
    $didb eval {
      INSERT INTO mem.links(tag,target,kind,fid)
      VALUES($tag, $target, $lki, $tsid)
      ON CONFLICT DO UPDATE SET target=$target
    }
  }
  if {$kind eq "BACK" || $kind eq "PAGE"} {
    # For backlinks and pagelinks, incoming values are appended, not stored.
    set ov [list $target]
    $didb eval {
      INSERT INTO mem.links(tag,target,kind,fid)
      VALUES($tag, $ov, $lki, $tsid)
      ON CONFLICT DO UPDATE SET target=tlist_append(target,$target)
    }
  }
  if {$kind eq "GLREF"} {
    # For glrefs, instances are counted per source making the reference.
    $didb eval {
      INSERT INTO mem.links(tag,target,kind,fid)
      VALUES($tag, 1, $lki, $tsid)
      ON CONFLICT DO UPDATE SET target=target+1
    }
  }
  if {$::doc_build_stats > 1} {
    set ks "$tag|$tsid"
    switch $kind {
      GLOBAL {
        incr ::global_link_count_s
        incr ::global_link_count_k($ks)
      }
      LOCAL {
        incr ::local_link_count_s
        incr ::local_link_count_k($ks)
      }
      BACK {
        incr ::back_link_count_s
        incr ::back_link_count_k($tag)
        incr ::back_link_count_ks($ks)
      }
      PAGE {
        incr ::page_link_count_s
        incr ::page_link_count_k($tag)
        incr ::page_link_count_ks($ks)
      }
    }
  }
}

proc unsatisfied_links {didb} {
  array set broken {}
  $didb eval {
    SELECT lr.fn AS fn, lr.tag AS tag
    FROM LinkRefs lr LEFT JOIN LinkDefs ld ON lr.tag=ld.tag
    WHERE ld.tag IS NULL
  } {
    lappend broken($tag) $fn
  }
  return [array get broken]
}

proc keep_links_fileinfo {didb} {
  $didb eval {
    INSERT INTO pages_in( file_name, file_length, mod_time, md5_digest )
    SELECT fname, length, mtime, hash FROM mem.link_sources WHERE TRUE
    ON CONFLICT(file_name) DO UPDATE SET
     file_length=excluded.file_length,
     mod_time=excluded.mod_time,
     md5_digest=excluded.md5_digest
  }
  $didb eval {
    UPDATE mem.links SET target=tsv_dedupe_norm(target)
    WHERE kind IN (2, 3)
  }
  $didb eval {
    INSERT INTO scan_links( tag, target, kind, fileid )
    SELECT m.tag, m.target, m.kind, pi.fileid
    FROM mem.links m, mem.link_sources ls, pages_in pi
    WHERE ls.fname=pi.file_name AND m.fid=ls.id
  }
  if {$::doc_build_linklog ne ""} {
    global tid2fname
    array set tid2fname {}
    $didb eval { SELECT fname, id FROM mem.link_sources } fi {
      set tid2fname($fi(id)) $fi(fname)
    }
    lldb eval { UPDATE lsl SET src=tid2fname(src) }
    file delete -force $::doc_build_linklog
    lldb eval {COMMIT; VACUUM INTO $::doc_build_linklog}
    lldb close
    set ::doc_build_linklog ""
  }
}

proc fetch_links {didb filelist} {
  set glinks {}
  set llinks {}
  set refs 0
  array set blinks {}
  array set plinks {}
  foreach fn $filelist {
    set fid [kidof_source $didb $fn]
    $didb eval {SELECT tag, target, kind FROM scan_links WHERE fileid=$fid} {
      # See ::lk above for significance of below 4 switch constants.
      switch $kind {
        0 {lappend glinks $tag $target; incr ::global_link_count_f}
        1 {lappend llinks $tag $target; incr ::local_link_count_f}
        2 {
          lappend blinks($tag) {*}[lsort [split $target "\t"]]
          incr ::back_link_count_f
        }
        3 {
          lappend plinks($tag) {*}[lsort [split $target "\t"]]
          incr ::page_link_count_f
        }
        4 { incr refs $target }
      }
      if {$::doc_build_linklog ne ""} {
        set tk $::lk($kind)
        if {$kind > 1} {set target [join [split $target "\t"] "|"]}
        lldb eval {
          INSERT INTO lfl(tag,target,kind,src) VALUES($tag,$target,$tk,$fn)
        }
      }
    }
  }
  foreach kw [lsort -nocase [array names blinks]] {
    set blinks($kw) [lsort -unique $blinks($kw)]
  }
  foreach kw [lsort -nocase [array names plinks]] {
    set plinks($kw) [lsort -unique $plinks($kw)]
  }
  return [list $glinks $llinks [array get blinks] [array get plinks] $refs ]
}

# Split filename list into two sets: {outdated or new} {up to date}
# The determination is made with respect to last successful doc gen run.
# Return list of 2 lists, in above order.
proc outdated_uptodate {didb filelist} {
  $didb eval {DELETE FROM mem.disk_sources}
  foreach fname $filelist {
    file lstat $fname fattr
    set fsz $fattr(size)
    set mt $fattr(mtime)
    $didb eval {
      INSERT INTO mem.disk_sources(fname,length,mtime)
      VALUES($fname, $fsz, $mt)
    }
  }
  $didb eval {
    -- Set hash just for files that appear possibly outdated.
    UPDATE mem.disk_sources AS mds
    SET outdated=
    CASE
      WHEN odq.clearly THEN true
      WHEN odq.maybe<>0 AND odq.hash<>file_hash(odq.fname) THEN true
      ELSE false END
    FROM
    (
     SELECT d.fname AS fname, pi.md5_digest AS hash,
      (pi.file_length IS NULL OR d.length <> pi.file_length) AS clearly,
      (pi.mod_time IS NOT NULL AND d.mtime > pi.mod_time) AS maybe
     FROM mem.disk_sources d LEFT JOIN pages_in pi ON pi.file_name=d.fname
    ) odq
    WHERE odq.fname = mds.fname
  }
  # For testing purposes, maybe fib about uptodate files being outdated.
  # This is convenient because the subjects of this fib will be treated
  # as if they had changed, but as actual input they are unchanged.
  if {[info exists ::env(DOC_BUILD_TOUCHES)]} {
    foreach fn [split $::env(DOC_BUILD_TOUCHES) " "] {
      if {$fn eq ""} continue
      $didb eval {UPDATE mem.disk_sources SET outdated=1 WHERE fname=$fn}
    }
  }
  # Set the output lists reflecting outdated and uptodate input filenames.
  set ods [$didb eval {
    SELECT d.fname FROM mem.disk_sources d WHERE d.outdated<>0
  }]
  set uds [$didb eval {
    SELECT d.fname FROM mem.disk_sources d WHERE d.outdated=0
  }]
  return [list $ods $uds]
}

proc full_build_clear {didb} {
  $didb eval { DELETE FROM pages_in; DELETE FROM scan_links }
}

proc report_inc_stats {didb} {
  puts "link array store|fetch counts:"
  set sfo "\
  glink: $::global_link_count_s|$::global_link_count_f\
  llink: $::local_link_count_s|$::local_link_count_f\
  blink: $::back_link_count_s|$::back_link_count_f\
  plink: $::page_link_count_s|$::page_link_count_f"
  puts $sfo
}
