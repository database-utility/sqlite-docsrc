#!./tclsh.docsrc
#
# This script processes raw documentation source text into a near-final HTML
# form for display by browsers. The processing actions are described below.
#
# Invoke this command as follows:
set usage \
  {   ./tclsh.docsrc wrap.tcl [mode pg_fname] $(DOC) $(SRC) $(DEST) <SOURCES>}
#
# where <SOURCES> is the remaining arguments naming input files,
# typically $(DOC)/pages/*.in expanded to a long list.
#
# When {mode pg_fname} is absent, a full scan and transformation of all
# named input files is done. This is appropriate for published builds.
#
# When mode eq "-update", only those input files which differ from
# their state after the previous build are scanned and transformed,
# and their names are left, one per line, in a file named by pg_fname.
# This is appropriate for doc development, prior to publishing results.
# The results have been tested for exact match to full build results.
# However, due to potential interactions between sources with embedded
# Tcl, this testing does not yet assure publication-ready results.
# Further, incremental builds do not leave behind the data used for
# the (traceability) matrix and evidence make targets.
#
# The $(DOC) and $(SRC) values are the names of directories containing
# the documentation source and program source. $(DEST) is the name of
# of the directory where generated HTML is written. <SOURCES> is a set
# of input files, source{1..N}.in, to be scanned and transformed, as
# necessary, into a set of output files, $(DEST)/source{1..N}.html .
#
# Changes made to the source files:
#
#     *  An appropriate header (containing the SQLite logo and standard
#        menu bar) is prepended to the file.
#
#     *  Any <title>...</title> in the input is moved into the prepended
#        header.
#
#     *  An appropriate footer is appended.
#
#     *  Scripts within <tcl>...</tcl> are evaluated.  Output that
#        is emitted from these scripts by "hd_puts" or "hd_resolve"
#        procedures appears in place of the original script.
#
#     *  Hyperlinks within [...] are resolved.
#
# A two-pass algorithm is used. The first full pass collects the names
# of hyperlink targets, requirements text, and other global information.
# The second pass uses the data gathered on the first pass to generate
# the final output.
#
# Full builds are suitable for both creating HTML and extracting data
# related to requirements and evidence of their testing.
#
# Incremental builds are also suitable for creating (revised) HTML, but
# do not leave data behind to be used for requirements and evidence.
################################################################

# For purposes of debugging or statistics collection, certain environment
# variables can be set to influence creation of auxiliary output files
# and informative console output. These are:
# DOC_BUILD_STATS   : If set to an integer, induces more console messages.
# DOC_BUILD_LINKLOG : If set, names DB where link defs and uses are logged.
# DOC_BUILD_TEMPDB  : If set, names DB used for staging (default :memory:)
# DOC_BUILD_TOUCHES : If set, lists input files which will be treated as
#   having been changed during incremental builds, even when unchanged.

# See what type of doc build this is, full or incremental.
set ::updating 0
if {$argc < 2} {
  puts stderr $usage
  exit 1
} elseif {[lindex $argv 0] eq "-update"} {
  set ::updating 1
  set ::pgfd [open [lindex $argv 1] w]
  incr argc -2
  set argv [lrange $argv 2 end]
}
if {$argc < 2} {
  puts stderr $usage
  exit 1
}
set ::DOC [lindex $argv 0]
set SRC [lindex $argv 1]
set DEST [lindex $argv 2]
set HOMEDIR [pwd]            ;# Also remember our home directory.

# If a certain env-var is set, emit some diagnostics
if {[info exists ::env(DOC_BUILD_STATS)]} {
  set ::doc_build_stats $::env(DOC_BUILD_STATS)
} else { set ::doc_build_stats 0 }

source [file dirname [info script]]/pages/fancyformat.tcl
source [file dirname [info script]]/document_header.tcl
source [file dirname [info script]]/pages/chronology.tcl
source [file dirname [info script]]/common_links.tcl
source [file dirname [info script]]/inc_update.tcl

# Some globals to help track where links originate, for incremental builds.
set ::currentInfile ""
set ::currentInfid 0

# Record errors for reporting after input files are processed.
# They are accumulated per input file for easier diagnosis.
array set ::accumulatedErrors {}
set ::errorCountTotal 0

# Record an error against ::currentInfile and return it
# (possibly for immediate output.)
proc record_error { errSay } {
  incr ::errorCountTotal
  if {![info exists ::accumulatedErrors($::currentInfile)]} {
    set yaps [list]
  } else {
    set yaps $::accumulatedErrors($::currentInfile)
  }
  lappend yaps $errSay
  set ::accumulatedErrors($::currentInfile) $yaps
  return "ERROR: $errSay"
}
# Put accumulated errors to a stream. Done near exit time for visibility.
proc dump_errors { ostrm } {
  foreach {infile} [lsort [array names ::accumulatedErrors]] {
    set errCount [llength $::accumulatedErrors($infile)]
    puts $ostrm "ERRORS from $infile ($errCount):"
    foreach {errMsg} $::accumulatedErrors($infile) {
      puts $ostrm "  $errMsg"
    }
  }
}

# Open the SQLite database.
#
sqlite3 db [file join $::DOC docinfo.db]
db eval "ATTACH '[file join $::DOC history.db]' AS history"

# All builds start with certain tables empty and populate them.
# Incremental builds also empty the tables upon completion to
# avoid problems from their content likely being incomplete due
# to that build process not being designed to update the tables.
proc clear_db_partial {db} {
  $db eval {
    BEGIN;
    DELETE FROM link;
    DELETE FROM keyword;
    DELETE FROM fragment;
    DELETE FROM page;
    DELETE FROM alttitle;
    DROP TABLE IF EXISTS expage;
  }
}
clear_db_partial db
# For full build, clear tables supporting incremental build.
if {!$::updating} { full_build_clear db }
# Setup transient tables for link/ref tracking in any case.
temp_links_setup db

# Load the syntax diagram linkage data
#
source $::DOC/art/syntax/syntax_linkage.tcl

# Gather hyperlink of 1 of 4 kinds. All link collection funnels through here.
proc gather_link {tag target kind {cfid 0}} {
  if {$cfid == 0} { set cfid $::currentInfid }
  if {$cfid != 0 && $::scan_pass < 3} {
    # Only record links set during pages/*.in scan and process.
    note_link db $tag $target $kind $cfid
  }
  switch $kind {
    GLOBAL { set ::glink($tag) $target }
    LOCAL  { set ::llink($tag) $target }
    BACK   { lappend ::backlink($tag) $target }
    PAGE   { lappend ::pagelink($tag) $target }
  }
  if {$::doc_build_stats > 0} { incr ::gather_stats("$::scan_pass|$kind") }
}

# Collect a global link reference, recording what source it comes from.
# These must be known to be satisfied during an incremental doc build
# when they are from an uptodate file and defined in an outdated file.
#
proc glref_add {t} {
  if {$::scan_pass > 2} return
  note_link db $t 0 GLREF $::currentInfid
}

# Return text of an <img...> that will load a syntax diagram
#
proc hd_syntax_diagram {path} {
  set name [file tail $path]
  set src $path.svg
  set in [open $::DOC/art/syntax/$name.pikchr rb]
  set txt [read $in]
  close $in
  set svg [pikchr $txt]
  set width [lindex $svg 1]
  if {$width<=0} {
    puts stderr [record_error "translating $::DOC/art/syntax/$name.pikchr"]
    return "<pre>[lindex $svg 0]</pre>\n"
  }
  set style "style=\"max-width:${width}px\""
  return "<div $style>[lindex $svg 0]</div>"
}

# Utility proc that removes excess leading and trailing whitespace.
#
proc hd_trim {txt} {
  regsub -all {\n\s+} $txt "\n" txt
  regsub -all {\s+\n} $txt "\n" txt
  return [string trim $txt]
}

# Create and initialize the associative link arrays.
# For a complete docs build, these are empty until page processing.
# For an incremental docs rebuild, they are pre-populated from the
# key-value pairs gathered during previous builds for non-stale input.
array set ::glink {} ;# global links -- Used by name in *.in Tcl content
array set ::llink {} ;# local links
array set ::backlink {} ;# backlinks -- Used by name in *.in Tcl content
array set ::pagelink {} ;# pagelinks

# This is the first-pass implementation of procedure that renders
# hyperlinks.  Do not even bother trying to do anything during the
# first pass.  We have to collect keyword information before the
# hyperlinks are meaningful.
#
proc hd_resolve {text} {
  hd_puts $text
}

# This is the second-pass implementation of the procedure that
# renders hyperlinks.  Convert all hyperlinks in $text into
# appropriate <a href=""> markup.
#
# Links to keywords within the same main file are resolved using
# $::llink() if possible.  All other links and links that could
# not be resolved using $::llink() are resolved using $::glink().
#
proc hd_resolve_2ndpass {text} {
  while {[regexp {<pikchr>(.*?)</pikchr>} $text all srctxt]} {
    set svg [pikchr $srctxt]
    set w [lindex $svg 1]
    if {$w>0} {
      set rep "<div style=\"max-width:${w}px;\">[lindex $svg 0]</div>"
    } else {
      puts stderr [record_error \
        "Pikchr translation error in $::infile\n[lindex $svg 0]\
          Original input:\n$srctxt\n"]
      break
    }
    regsub {<pikchr>.*?</pikchr>} $text $rep text
  }
  regsub -all {<(yy(non)?term)>} $text {<span class='\1'>} text
  regsub -all {</yy(non)?term>} $text {</span>} text
  regsub -all {\[(.*?)\]} $text \
      "\175; hd_resolve_one \173\\1\175; hd_puts \173" text
  eval "hd_puts \173$text\175"
}
proc hd_resolve_one {x} {
  if {[string is integer $x] || [string length $x]==1} {
    hd_puts \[$x\]
    return
  }
  if {[string match {dateof:3.*} $x]} {
    set x [string range $x 7 end]
    if {[info exists ::dateofversion($x)]} {
      hd_puts $::dateofversion($x)
    } else {
      puts stderr [record_error "*** unresolved date: '\[dateof:$x\]' ***"]
      hd_puts "<font color='red'>0000-00-00</font>"
    }
    return
  }
  set x2 [split $x |]
  set kw [string trim [lindex $x2 0]]
  if {[llength $x2]==1} {
    set content $kw
    regsub {\([^)]*\)} $content {} kw
    if {![regexp {^http} $kw]} {regsub {=.*} $kw {} kw}
  } else {
    set content [string trim [lindex $x2 1]]
  }
  if {![regexp {^https?:} $kw]} {
    regsub -all {[^a-zA-Z0-9_.#/ -]} $kw {} kw
  }
  global hd
  if {$hd(enable-main)} {
    set fn $hd(fn-main)
    if {[regexp {^https?:} $kw]} {
      puts -nonewline $hd(main) \
        "<a href=\"$kw\">$content</a>"
    } elseif {[regexp {^[Tt]icket #(\d+)$} $kw all tktid]} {
      set url http://www.sqlite.org/cvstrac/tktview?tn=$tktid
      puts -nonewline $hd(main) \
        "<a href=\"$url\">$content</a>"
    } elseif {[info exists ::llink($fn:$kw)]} {
      puts -nonewline $hd(main) \
        "<a href=\"$hd(rootpath-main)$::llink($fn:$kw)\">$content</a>"
    } elseif {[info exists ::glink($kw)]} {
      puts -nonewline $hd(main) \
        "<a href=\"$hd(rootpath-main)$::glink($kw)\">$content</a>"
      glref_add $kw
    } else {
      puts stderr [record_error "unknown hyperlink target: $kw"]
      puts -nonewline $hd(main) "<font color=\"red\">$content</font>"
    }
    if {$hd(fragment)!=""} {
      backlink_add $kw $fn#$hd(fragment)
    } else {
      backlink_add $kw $fn
    }
  }
  if {$hd(enable-aux)} {
    if {[regexp {^https?:} $kw]} {
      puts -nonewline $hd(aux) \
        "<a href=\"$kw\">$content</a>"
    } elseif {[regexp {^[Tt]icket #(\d+)$} $kw all tktid]} {
      set url http://www.sqlite.org/cvstrac/tktview?tn=$tktid
      puts -nonewline $hd(aux) \
        "<a href=\"$url\">$content</a>"
    } elseif {[info exists ::glink($kw)]} {
      puts -nonewline $hd(aux) \
        "<a href=\"$hd(rootpath-aux)$::glink($kw)\">$content</a>"
      glref_add $kw
    } else {
      puts stderr [record_error "unknown hyperlink target: $kw"]
      puts -nonewline $hd(aux) "<font color=\"red\">$content</font>"
    }
    if {$hd(aux-fragment)!=""} {
      backlink_add $kw $hd(fn-aux)#$hd(aux-fragment)
    } else {
      backlink_add $kw $hd(fn-aux)
    }
  }
}

# Convert the keyword $kw into an appropriate relative URI
# This is a helper routine to hd_list_of_links
#
proc hd_keyword_to_uri {kw} {
  global hd
  if {[string match {*.html} $kw]} {return $kw}
  if {$hd(enable-main)} {
    set fn $hd(fn-main)
    set res ""
    if {[info exists ::llink($fn:$kw)]} {
      set res "$hd(rootpath-main)$::llink($fn:$kw)"
    } elseif {[info exists ::glink($kw)]} {
      set res "$hd(rootpath-main)$::glink($kw)"
      glref_add $kw
    }
    if {$res!=""} {
      if {$hd(fragment)!=""} {
        backlink_add $kw $fn#$hd(fragment)
      } else {
        backlink_add $kw $fn
      }
    }
    return $res
  }
  if {$hd(enable-aux)} {
    if {[info exists ::glink($kw)]} {
      if {$hd(aux-fragment)!=""} {
        backlink_add $kw $hd(fn-aux)#$hd(aux-fragment)
      } else {
        backlink_add $kw $hd(fn-aux)
      }
      glref_add $kw
      return $hd(rootpath-aux)$::glink($kw)
    }
  }
  return ""
}

# Output HTML/JS that displays the list $lx in multiple columns
# under the assumption that each column is $w pixels wide.  The
# number of columns automatically adjusts to fill the available
# screen width.
#
# If $title is not an empty string, then it is used as a title for
# the list of links
#
# $lx is a list of triples.  Each triple is {KEYWORD LABEL S}.  The
# S determines a suffix added to each list element:
#
#    0:     Add nothing (the default and common case)
#    1:     Add the "(exp)" suffix
#    2:     Strike through the text and do not hyperlink
#    3:     Strike through the text and add &sup1
#    4:     Add &sup2
#    5:     Add &sup3
#
proc hd_list_of_links {title w lx} {
  global hd
  set w [expr {$w/20}]em
  hd_puts "<div class='columns' style='columns: ${w} auto;'>\n"
  hd_puts "<ul style='padding-top:0;'>\n"
  foreach x $lx {
    foreach {kw lbl s} $x break
    set suffix {}
    set prefix {}
    switch $s {
      1 {set suffix "<small><i>(exp)</i></small>"}
      2 {set suffix "</s>"; set prefix "<s>"; set kw ""}
      3 {set suffix "&sup1;</s>"; set prefix "<s>"}
      4 {set suffix "&sup2;"}
      5 {set suffix "&sup3;"}
    }
    if {$kw!=""} {
      if {$hd(enable-main) && $hd(enable-aux)} {
        set hd(enable-main) 0
        set url [hd_keyword_to_uri $kw]
        hd_puts "<li><a href='$url'>$prefix$lbl$suffix</a></li>\n"
        set hd(enable-main) 1
        set hd(enable-aux) 0
        set url [hd_keyword_to_uri $kw]
        hd_puts "<li><a href='$url'>$prefix$lbl$suffix</a></li>\n"
        set hd(enable-aux) 1
      } else {
        set url [hd_keyword_to_uri $kw]
        hd_puts "<li><a href='$url'>$prefix$lbl$suffix</a></li>\n"
      }
    } else {
      hd_puts "<li>$prefix$lbl$suffix</li>\n"
    }
  }
  hd_puts "</ul>\n"
  hd_puts "</div>\n"
}

# Record the fact that all keywords given in the argument list should
# cause a jump to the current location in the current file.
#
# If only the main output file is open, then all references to the
# keyword jump to the main output file.  If both main and aux are
# open then references from within the main file jump to the main file
# and all other references jump to the auxiliary file.
#
# This procedure is only active during the first pass when we are
# collecting hyperlink information.  This procedure is redefined to
# be a no-op before the start of the second pass.
#
proc hd_keywords {args} {
  global hd
  if {$hd(fragment)==""} {
    set lurl $hd(fn-main)
  } else {
    set lurl "#$hd(fragment)"
  }
  set fn $hd(fn-main)
  if {[info exists hd(aux)]} {
    set gurl $hd(fn-aux)
    if {$hd(aux-fragment)!=""} {
      append gurl "#$hd(aux-fragment)"
    }
  } else {
    set gurl {}
    if {$hd(fragment)!=""} {
      set lurl $hd(fn-main)#$hd(fragment)
    }
  }
  set override_flag 0
  foreach a $args {
    if {[regexp {^-+(.*)} $a all param] && ![regexp {^-D} $a]} {
      switch $param {
        "override" {
           set override_flag 1
        }
        default {
          puts stderr [record_error "unknown parameter: $a"]
        }
      }
      continue
    }
    if {[regexp {^\*} $a]} {
      set visible 0
      set a [string range $a 1 end]
    } else {
      set visible 1
    }
    if {[regexp {^/--} $a]} {set a [string range $a 1 end]}
    regsub -all {[^a-zA-Z0-9_.#/ -]} $a {} kw
    if {[info exists ::glink($kw)]} {
      if {[info exists hd(aux)] && $::glink($kw)==$hd(fn-aux)} {
        db eval {DELETE FROM keyword WHERE kw=$kw}
      } elseif {$override_flag==0} {
        puts stderr [record_error \
               "WARNING: duplicate keyword \"$kw\" - $::glink($kw) and $lurl"]
      }
    }
    if {$gurl==""} {
      gather_link $kw $lurl GLOBAL
      db eval {INSERT OR IGNORE INTO keyword(kw,fragment,indexKw)
                VALUES($a,$lurl,$visible)}
    } else {
      gather_link $kw $gurl GLOBAL
      gather_link $fn:$kw $lurl LOCAL
      db eval {INSERT OR IGNORE INTO keyword(kw,fragment,indexKw)
                VALUES($a,$gurl,$visible)}
    }
  }
}

# Start a new fragment in the main file.  Give the new fragment the
# indicated name.  Any keywords defined after this point will refer
# to the fragment, not to the beginning of the file.
#
proc hd_fragment {name args} {
  global hd
  set hd(fragment) $name
  puts $hd(main) "<a name=\"$name\"></a>"
  if {$hd(enable-aux)} {
    puts $hd(aux) "<a name=\"$name\"></a>"
    set hd(aux-fragment) $name
  }
  eval hd_keywords $args
}

# Current output doc path sans tail.
proc out_dir {} {
  global hd
  if {$hd(enable-aux)} {
    return $hd(rootpath-aux)
  } else {
    return $hd(rootpath-main)
  }
}

# Pre-filtering and funneling for added backlinks.
proc backlink_add {t r} {
  # Filter out self-references for obviousness.
  if {$t eq $r} return
  gather_link $t $r BACK
}

# Pre-filtering and funneling for added pagelinks.
proc pagelink_add {t r} {
  # Do not add compendium refs to the compendia. Too obvious and useless.
  if {[regexp {^doc_.*} $r]} return
  if {$t eq $r} return
  # Fixup (useless and duplicate-generating) relative-to-. page links.
  set t [regsub {^\.\/} $t ""]
  gather_link $t $r PAGE
}

# Write raw output to both the main file and the auxiliary.
# Only write after first pass to files that are enabled.
#
proc hd_puts {text} {
  if {$::scan_pass < 2} return
  global hd
  if {$hd(enable-main)} {
    set fn $hd(fn-main)
    puts -nonewline $hd(main) $text
  }
  if {$hd(enable-aux)} {
    set fn $hd(fn-aux)
    puts -nonewline $hd(aux) $text
  }

  # Our post-pass pagelink processing based off the globals
  # ::llink, ::glink, and ::backlink generated during hd_resolve
  # processing doesn't catch links output directly with hd_puts.
  # This code adds those links to our pagelink array, ::pagelink.
  set refs [regexp -all -inline {href=\"(.*?)\"} $text]
  foreach {href ref} $refs {
    regsub {#.*} $ref {} ref2
    regsub {http:\/\/www\.sqlite\.org\/} $ref2 {} ref3
    if {[regexp {^checklists\/} $ref3]} continue
    regsub {\.\.\/} $ref3 {} ref4
    if {[regexp {^http} $ref4]} continue
    if {$ref4==""} continue
    if {[regexp {\.html$} $ref4]} {
      pagelink_add $ref4 $fn
    }
  }
}
proc hd_putsnl {text} {
  hd_puts $text\n
}

# Enable or disable the main output file.
#
proc hd_enable_main {boolean} {
  global hd
  set hd(enable-main) $boolean
}

# Enable or disable the auxiliary output file.
#
proc hd_enable_aux {boolean} {
  global hd
  set hd(enable-aux) $boolean
}
set hd(enable-aux) 0

# Open the main output file.  $filename is relative to $::DEST.
#
proc hd_open_main {filename} {
  global hd DEST
  hd_close_main
  set hd(fn-main) $filename
  set hd(rootpath-main) [hd_rootpath $filename]
  set hd(main) [open $DEST/$filename w]
  set hd(enable-main) 1
  set hd(enable-aux) 0
  set hd(footer) {}
  set hd(fragment) {}
  pagelink_add $filename $filename
}

# If $filename is a path from $::DEST to a file, return a path
# from the directory containing $filename back to the directory $::DEST.
#
proc hd_rootpath {filename} {
  set up {}
  set n [llength [split $filename /]]
  if {$n<=1} {
    return {}
  } else {
    return [string repeat ../ [expr {$n-1}]]
  }
}

# Close the main output file.
#
proc hd_close_main {} {
  global hd
  hd_close_aux
  if {[info exists hd(main)]} {
    puts $hd(main) $hd(mtime-msg)
    puts $hd(main) $hd(footer)
    close $hd(main)
    unset hd(main)
    set hd(rootpath-main) ""
  }
}

# Open the auxiliary output file.
#
# Most documents have only a main file and no auxiliary.  However, some
# large documents are broken up into smaller pieces where each smaller piece
# is an auxiliary file.  There will typically be either many auxiliary files
# or no auxiliary files associated with each main file.
#
proc hd_open_aux {filename} {
  global hd DEST
  hd_close_aux
  set hd(fn-aux) $filename
  set hd(rootpath-aux) [hd_rootpath $filename]
  set hd(aux) [open $DEST/$filename w]
  set hd(enable-aux) 1
  set hd(aux-fragment) {}
  pagelink_add $filename $filename
  # Add to list of outputs subject to caret removal.
  if {$::updating && $::scan_pass == 2} {
    puts $::pgfd $DEST/$filename
  }
}

# Close the auxiliary output file
#
proc hd_close_aux {} {
  global hd
  if {[info exists hd(aux)]} {
    puts $hd(aux) $hd(mtime-msg)
    puts $hd(aux) $hd(footer)
    close $hd(aux)
    unset hd(aux)
    unset hd(fn-aux)
    set hd(enable-aux) 0
    set hd(enable-main) 1
  }
}

# Pages call this routine to suppress the bottom "Page Last Modified" message.
#
proc hd_omit_mtime {} {
  global hd
  set hd(mtime-msg) {}
}

# hd_putsin4 is like puts except that it removes the first 4 indentation
# characters from each line.  It also does variable substitution in
# the namespace of its calling procedure.
#
proc putsin4 {fd text} {
  regsub -all "\n    " $text \n text
  puts $fd [uplevel 1 [list subst -noback -nocom $text]]
}

# For each .in file, generate a globally unique object id sequence.
# This one is made from a PRNG seeded with a 128-bit hash of the .in filename.
# As each input's pass 2 starts, the PRNG is seeded deterministically so that
# generated files are created identically as long as their .in is unchanged.
# This allows incremental and full doc builds to produce identical outputs.
#
set ::id_prng ""
set ::id_part 0
proc seed_id {hv} {
  set ::id_prng $hv
  set ::id_part 0
}
# Return successive values from the sequence as the id.
#
proc hd_id {} {
  set ixb $::id_part
  set ixe [incr ::id_part 8]
  set hvs [string range $::id_prng $ixb [expr $ixe - 1]]
  if {$ixe >= 32} {
    set ::id_prng [md5 "$::id_prng $::currentInfile"]
    set ::id_part 0
  }
  return x$hvs
}

# Function to retrieve some SCM-related facts about a source file.
# Return list of normalizedFilename artifactId checkinTimestamp .
#
proc scm_facts_for {infn} {
  set fname ""; set arid ""; set cits ""; set date ""; set ckin ""
  try {
    set finfo [exec fossil finfo -l -n 1 $infn]
    foreach {hln vln} [lrange [split $finfo "\n"] 0 1] break
    regexp {History for ([[:graph:]]+)$} $hln _ fname
    regexp {^([-0-9]{10}) \[([0-9a-f]+)\]} $vln _ date ckin
    regexp {artifact: +\[([0-9a-f]+)\]} $finfo _ arid
    if {$ckin ne ""} {
      foreach iln [split [exec fossil info $ckin] "\n"] {
        if {[regexp {^hash:} $iln]} {
          regexp {([-0-9]{10} [0-9:]{8}) UTC$} $iln _ cits
          break
        }
      }
    }
  } on error erc {
    if {[incr ::fossilFails] < 2} { puts stderr "fossil invoke fails: $erc" }
  }
  return [list $fname $arid $cits]
}

# A procedure to write the common header found on every HTML file on
# the SQLite website.
#
proc hd_header {title {srcfile {}}} {
  global hd
  set saved_enable $hd(enable-main)
  if {$srcfile==""} {
    set fd $hd(aux)
    set path $hd(rootpath-aux)
  } else {
    set fd $hd(main)
    set path $hd(rootpath-main)
  }

  puts $fd [document_header $title $path]
  set hd(mtime-msg) {}
  if {$srcfile!=""} {
    set owd [pwd]
    cd [file dir $srcfile]
    foreach {fname arid cits} [scm_facts_for [file tail $srcfile]] break
    cd $owd
    if {$arid ne "" && $cits ne ""} {
      set hd(mtime-msg) [hd_trim \
 ""]
      if {[file exists DRAFT]} {
        set hd(footer) [hd_trim {
          <p align="center"><font size="6" color="red">*** DRAFT ***</font></p>
        }]
      } else {
        set hd(footer) {}
      }
    }
  } else {
    set hd(enable-main) $saved_enable
  }
}

# Insert a bubble syntax diagram into the output.
#
proc BubbleDiagram {name {anonymous_flag 0}} {
  global hd

  #if {!$anonymous_flag} {
  #  hd_resolve "<h4>\[$name:\]</h4>"
  #}
  hd_resolve "<p><b>\[$name:\]</b></p>"
  set alt "alt=\"syntax diagram $name\""
  if {$hd(enable-main)} {
    puts $hd(main) "<div class='imgcontainer'>\n\
        [hd_syntax_diagram $hd(rootpath-main)images/syntax/$name]\n\
        </div>"
  }
  if {$hd(enable-aux)} {
    puts $hd(aux) "<div class='imgcontainer'>\n\
        [hd_syntax_diagram $hd(rootpath-aux)images/syntax/$name]\n\
        </div>"
  }
}
proc HiddenBubbleDiagram {name} {
  global hd
  set alt "alt=\"syntax diagram $name\""
  hd_resolve "<p><b>\[$name:\]</b> "
  if {$hd(enable-main)} {
    set a [hd_id]
    set b [hd_id]
    puts $hd(main) \
     "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>show</button>\
      </p>\n\
      <div id='$b' style='display:none;' class='imgcontainer'>\n\
      [hd_syntax_diagram $hd(rootpath-main)images/syntax/$name]\n\
      </div>"
  }
  if {$hd(enable-aux)} {
    set a [hd_id]
    set b [hd_id]
    puts $hd(aux) \
     "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>show</button>\
      </p>\n\
      <div id='$b' style='display:none;' class='imgcontainer'>\n\
      [hd_syntax_diagram $hd(rootpath-aux)images/syntax/$name]\n\
      </div>"
  }
}
proc RecursiveBubbleDiagram_helper {class name openlist exclude} {
  global hd syntax_linkage DEST
  set alt "alt=\"syntax diagram $name\""
  hd_resolve "<p><b>\[$name:\]</b>\n"
  set a [hd_id]
  set b [hd_id]
  set openflag 0
  set open2 {}
  foreach x $openlist {
    if {$x==$name} {
      set openflag 1
    } else {
      lappend open2 $x
    }
  }
  if {$openflag} {
    puts $hd($class) \
      "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>hide</button></p>\n\
       <div id='$b' class='imgcontainer'>\n\
       [hd_syntax_diagram $hd(rootpath-$class)images/syntax/$name]"
  } else {
    puts $hd($class) \
      "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>show</button></p>\n\
       <div id='$b' style='display:none;' class='imgcontainer'>\n\
       [hd_syntax_diagram $hd(rootpath-$class)images/syntax/$name]"
  }
  if {[info exists syntax_linkage($name)]} {
    foreach {cx px} $syntax_linkage($name) break
    foreach c $cx {
      if {[lsearch $exclude $c]>=0} continue
      RecursiveBubbleDiagram_helper $class $c $open2 [concat $exclude $cx]
    }
  }
  puts $hd($class) "</div>"
}
proc RecursiveBubbleDiagram {args} {
  global hd
  set show 1
  set a2 {}
  foreach name $args {
    if {$name=="--initially-hidden"} {
      set show 0
    } else {
      lappend a2 $name
    }
  }
  if {$show} {
    set showlist $a2
  } else {
    set showlist {}
  }
  set name [lindex $a2 0]
  if {$hd(enable-main)} {
    RecursiveBubbleDiagram_helper main $name $showlist $name
  }
  if {$hd(enable-aux)} {
    RecursiveBubbleDiagram_helper aux $name $showlist $name
  }
}


# Insert a See Also line for related bubble

# Record a requirement.  This procedure is active only for the first
# pass.  This procedure becomes a no-op for the second pass.  During
# the second pass, requirements listing report generators can use the
# data accumulated during the first pass to construct their reports.
#
# If the "verbatim" argument is true, then the requirement text is
# rendered as is.  In other words, the requirement text is assumed to
# be valid HTML with all hyperlinks already resolved.  If the "verbatim"
# argument is false (the default) then the requirement text is rendered
# using hd_render which will find an expand hyperlinks within the text.
#
# The "comment" argument is non-binding commentary and explanation that
# accompanies the requirement.
#
proc hd_requirement {id text derivedfrom comment} {
  global ALLREQ ALLREQ_DERIVEDFROM ALLREQ_COM
  if {[info exists ALLREQ($id)]} {
    puts stderr [record_error "duplicate requirement label: $id"]
  }
  set ALLREQ_DERIVEDFROM($id) $derivedfrom
  set ALLREQ($id) $text
  set ALLREQ_COM($id) $comment
}

# Read a block of requirements from an ASCII text file.  Store the
# information obtained in a global variable named by the second parameter.
#
proc hd_read_requirement_file {filename varname} {
  global hd_req_rdr
  hd_reset_requirement_reader
  set in [open $filename]
  while {![eof $in]} {
    set line [gets $in]
    if {[regexp {^(HLR|UNDEF|SYSREQ) +([LHSU]\d+) *(.*)} $line _ type rn df]} {
      hd_add_one_requirement $varname
      set hd_req_rdr(rn) $rn
      set hd_req_rdr(derived) $df
    } elseif {[string trim $line]==""} {
      if {$hd_req_rdr(body)==""} {
        set hd_req_rdr(body) $hd_req_rdr(comment)
        set hd_req_rdr(comment) {}
      } else {
        append hd_req_rdr(comment) \n
      }
    } else {
      append hd_req_rdr(comment) $line\n
    }
  }
  hd_add_one_requirement $varname
  close $in
}
proc hd_reset_requirement_reader {} {
  global hd_req_rdr
  set hd_req_rdr(rn) {}
  set hd_req_rdr(comment) {}
  set hd_req_rdr(body) {}
  set hd_req_rdr(derived) {}
}
proc hd_add_one_requirement {varname} {
  global hd_req_rdr
  set rn $hd_req_rdr(rn)
  if {$rn!=""} {
    if {$hd_req_rdr(body)==""} {
      set hd_req_rdr(body) $hd_req_rdr(comment)
      set hd_req_rdr(comment) {}
    }
    set b [string trim $hd_req_rdr(body)]
    set c [string trim $hd_req_rdr(comment)]
    set ::${varname}($rn) [list $hd_req_rdr(derived) $b $c]
    lappend ::${varname}(*) $rn
  }
  hd_reset_requirement_reader
}

# Determine which of specified infiles to actually scan and transform,
# and populate the link arrays accordingly. (No stale links to remain.)
set infiles [lrange $argv 3 end]

if {$::updating} {
  foreach {odfiles udfiles} [outdated_uptodate db $infiles] break
  set nod [llength $odfiles]
  set nud [llength $udfiles]
  # Pre-populate ::glink, ::llink, ::backlink, ::pagelink arrays
  # from the DB while omitting elements gleaned from the outdated inputs.
  set lcount 0
  foreach {g l b p ref_count} [fetch_links db $udfiles] {
    array set ::glink $g
    incr lcount [array size ::glink]
    array set ::llink $l
    incr lcount [array size ::llink]
    array set ::backlink $b
    incr lcount [array size ::backlink]
    array set ::pagelink $p
    incr lcount [array size ::pagelink]
  }
  puts "Reusing $lcount links from $nud files to process $nod files."
  puts "Possibly resolving $ref_count link references from $nud files."
  set infiles $odfiles
}

array set ::dateofversion {}
# Get date/version info used by chronology.in, which may remain unprocessed.
foreach {udvv} [chronology_info] {
  foreach {uuid date vers vnum} $udvv break
  set ::dateofversion($vers) $date
}

# Normalize the appendee associative arrays value lists and rebuild them to
# make generated crossref pages the same between full and incremental builds.
#
proc normalize_apparray {aaName} {
  set blv [lsort -nocase -stride 2 [array get $aaName]]
  array unset $aaName
  foreach {k v} $blv {
    array set $aaName [list $k [lsort -unique $v]]
  }
  unset blv
}

# Dump key value pairs of an over-written style link array, as Tcl commands.
#
proc dump_ow_links { owaName ofd } {
  foreach v [lsort [array names $owaName]] {
    puts $ofd "set k \"$v\"; set ${owaName}(\$k) {[set ${owaName}($v)]}"
  }
  puts $ofd "unset k"
}

# Dump key value pairs of an appended-upon style link array, as Tcl commands.
#
proc dump_ap_links { apaName ofd } {
  foreach v [lsort [array names $apaName]] {
    puts -nonewline $ofd "set k \"$v\"; "
    puts -nonewline $ofd [string cat "lappend $apaName" "(\$k) {*}\[split \""]
    set ve [eval [string cat {set } $apaName {($v)}]]
    puts -nonewline $ofd [join [lsort $ve] "\t"]
    puts $ofd {" "\t"]}
  }
  puts $ofd "unset k"
}

# (Maybe) show a hash for a link array. Used for simple verification that such
# an array is identical after processing between full and incremental builds.
#
if {$::doc_build_stats > 0} {
  # Diagnostic aid for link array contents.
  proc show_array_hash {args} {
    foreach aName $args {
      upvar $aName a
      puts "$aName hash: [md5 [join [lsort -stride 2 [array get a]] {!}]]"
    }
  }
} else {
  proc show_array_hash {args} {}
}

# Keep input hashes for id sequence generation.
array set ::in_hashes {}

# If dbs bit 3 set, instrument creation/use of procs over pass 1 scan.
# Detect and report any proc defined in x.in then called from y.in ,
# instances of which will be problematic for incremental docs build.
if {($::doc_build_stats & 8) != 0} {
  rename proc built-in-proc
  built-in-proc proc {name args body} {
    if {![regexp {^::hdom::} $name] && $::scan_pass == 1} {
      set prepend "if {\$::currentInfile ne \"$::currentInfile\"} {\n
        puts stderr \"proc $name cross-called from \$::currentInfile\"\n
      }"
      set body "$prepend\n$body"
    }
    built-in-proc $name $args $body
  }
}

# First pass. Process input files. But do not render hyperlinks.
# Merely collect keyword and reference information so that links
# can be correctly rendered (or detected broken) on second pass.
#
set ::scan_pass 1 ;# Variable used locally and within scanned sources.

if {!($::doc_build_stats & 1)} {
  puts -nonewline "Gathering links from [llength $infiles] input files ."
}
set num_scanned 0
foreach infile $infiles {
  cd $HOMEDIR
  if {$::doc_build_stats & 1} {
    puts "Gathering links from $infile"
  } else {
    if {[incr num_scanned] % 6 == 0} {puts -nonewline . ; flush stdout}
  }
  set ::currentInfile $infile
  set fd [open $infile r]
  set in [read $fd]
  close $fd
  set hash [md5 $in]
  set ::in_hashes($::currentInfile) $hash
  set ::currentInfid [note_source db $infile $hash]

  if {[regexp {<(fancy_format|table_of_contents)>} $in]} {
    set in [addtoc $in]
  }
  set title {No Title}
  regexp {<title>([^\n]*)</title>} $in all title
  regsub {<title>[^\n]*</title>} $in {} in
  set outfile [file root [file tail $infile]].html
  hd_open_main $outfile
  db eval {
    INSERT INTO page(filename,pagetitle)
    VALUES($outfile,$title);
  }
  set h(pageid) [db last_insert_rowid]
  while {[regexp {<alt-title>([^\n]*)</alt-title>} $in all alttitle]} {
    regsub {<alt-title>[^\n]*</alt-title>} $in {} in
    db eval {
      INSERT INTO alttitle(alttitle,pageid) VALUES($alttitle,$h(pageid));
    }
  }
  hd_header $title $infile
  regsub -all {<tcl>} $in "\175; eval \173" in
  regsub -all {</tcl>} $in "\175; hd_puts \173" in
  if {[catch {eval hd_puts "\173$in\175"} err]} {
    puts "\nERROR in $infile"
    puts [string range "$::errorInfo\n$in" 0 200]
    exit 1
  }
  cd $::HOMEDIR
  hd_close_main
  set ::currentInfid 0
  set ::currentInfile ""
}
if {!($::doc_build_stats & 1)} {puts ""}

# Undo the proc define/use instrumentation setup above.
if {($::doc_build_stats & 8) != 0} {
  rename proc ""
  rename built-in-proc proc
}

# Second pass. Process input files again. This time render hyperlinks
# according to the keyword information collected on the first pass.
#
proc hd_keywords {args} {}
rename hd_resolve {}
rename hd_resolve_2ndpass hd_resolve
proc hd_requirement {args} {}

set ::scan_pass 2

proc footer_too {} {}
# proc footer_too {} {
#   source [file normalize [file join $::DOC pages footer.tcl]]
# }

if {!($::doc_build_stats & 1)} {
  puts -nonewline "Transforming [llength $infiles] files to $DEST/*.html ."
}
set num_resolved 0
foreach infile $infiles {
  cd $HOMEDIR
  if {$::doc_build_stats & 1} {
    puts -nonewline "Transforming $infile to $DEST/$outfile"
  } else {
    if {[incr num_resolved] % 6 == 0} {puts -nonewline . ; flush stdout}
  }
  set ::currentInfile $infile
  set ::currentInfid [tidof_source db $infile]
  set outfile [file root [file tail $infile]].html
  set fd [open $infile r]
  set in [read $fd]
  close $fd
  seed_id $::in_hashes($::currentInfile)
  regsub -all {<alt-title>[^\n]*</alt-title>} $in {} in
  if {[regexp {<(fancy_format|table_of_contents)>} $in]} {
    set in [addtoc $in]
  }
  set title {No Title}
  regexp {<title>([^\n]*)</title>} $in all title
  regsub {<title>[^\n]*</title>} $in {} in
  hd_open_main $outfile
  if {$::updating} {
    puts $::pgfd $DEST/$outfile
  }
  hd_header $title $infile
  regsub -all {<tcl>} $in "\175; eval \173" in
  regsub -all {</tcl>} $in "\175; hd_resolve \173" in
  eval "hd_resolve \173$in\175"
  footer_too
  cd $::HOMEDIR
  hd_close_main
  set ::currentInfid 0
  set ::currentInfile ""
}
if {!($::doc_build_stats & 1)} {puts ""}

set ::scan_pass 3
# Processing from here on uses only variables already set.
# No further link sets are kept in the docinfo.db DB.

set broken_glinks [unsatisfied_links db]

# Get the appended-upon link arrays into a normalized condition.
normalize_apparray ::backlink
normalize_apparray ::pagelink
# And maybe show their hashes (for debug.)
show_array_hash ::glink ::llink ::backlink ::pagelink

# Generate 4 documents showing the hyperlink keywords and their targets,
# restricted to those relating to the main body of the documentation.

hd_open_main doc_keyword_crossref.html
hd_header {Keyword Crossreference} $::DOC/wrap.tcl
hd_puts "<ul>"
foreach x [lsort -dict [array names ::glink]] {
  set y $::glink($x)
  hd_puts "<li>$x - <a href=\"$y\">$y</a></li>"
  lappend ::revglink($y) $x
}
hd_puts "</ul>"
hd_close_main

show_array_hash ::revglink

hd_open_main doc_target_crossref.html
hd_header {Target Crossreference} $::DOC/wrap.tcl
hd_putsnl "<ul>"
foreach y [lsort [array names revglink]] {
  hd_putsnl "<li><a href=\"$y\">$y</a> &rarr; [lsort $revglink($y)]</li>"
}
hd_putsnl "</ul>"
hd_close_main

hd_open_main doc_backlink_crossref.html
hd_header {Backlink Crossreference} $::DOC/wrap.tcl
hd_puts "<ul>"
foreach kw [lsort -nocase [array names ::backlink]] {
  hd_puts "<li>$kw &rarr;"
  foreach ref [lsort -unique $::backlink($kw)] {
    hd_putsnl "  <a href=\"$ref\">$ref</a>"
  }
}
hd_putsnl "</ul>"
hd_close_main

# Will suppress mentioning these in hyperlink compendia.
set ::tossers {(news|changes|releaselog|[0-9]to[0-9]|^doc_[^_]+_crossref)}
proc tossable_xref {v} {
 return [regexp $::tossers $v]
}

hd_open_main doc_pagelink_crossref.html
hd_header {Pagelink Crossreference} $::DOC/wrap.tcl
hd_puts \
"<p>Key: Target_Page &rarr; pages that have hyperlinks to the target page.</p>"
hd_puts \
"<p>Pages matching [regsub -all {\^} $::tossers {\&#94;}] are skipped.</p>"
hd_puts "<ul>"
foreach y [lsort [array names revglink]] {
  regsub {#.*} $y {} y2
  foreach kw [lsort $revglink($y)] {
    if {[info exists ::backlink($kw)]} {
      foreach ref $::backlink($kw) {
        regsub {#.*} $ref {} ref2
        if {$::doc_build_stats > 0 && ![file exists "doc/$y2"]} {
          puts stderr "Goofy pagelink $y2"
        }
        pagelink_add $y2 $ref2
      }
    }
  }
}
normalize_apparray ::pagelink

foreach y [lsort [array names ::pagelink]] {
  if {[tossable_xref $y]} continue
  if {$::doc_build_stats > 0 && ![file exists "doc/$y"]} {
    puts stderr "Goofy pagelink $y"
  }
  set plo [list]
  foreach ref [lsort -unique $::pagelink($y)] {
    if {$ref==$y || [tossable_xref $ref]} continue
    lappend plo $ref
  }
  if {[llength $plo] == 0} continue
  regsub {^\.\./} $y {} sy
  hd_putsnl "<li><a href=\"$y\">$sy</a> &rarr; "
  foreach ref $plo {
    regsub {^\.\./} $ref {} sref
    hd_puts "<a href=\"$ref\">$sref</a> "
  }
  hd_putsnl "</li>"
}
hd_puts "</ul>"
hd_close_main

if {$::doc_build_stats > 0} {
  # Show links modified by kind and pass.
  foreach gst [lsort [array names ::gather_stats]] {
    puts "$gst count: $::gather_stats($gst)"
  }
}

# If build succeeded, preserve file and link info just gathered for later
# incremental builds. Without this, next faster build will repeat its work.
# Such repetition is desirable when diagnosing and fixing broken links.
if {[llength $broken_glinks] > 0} {
  array set broken $broken_glinks
  incr ::errorCountTotal [llength [array names broken]]
  puts "Unsatisfied global link references:"
  foreach tag [lsort [array names broken]] {
    puts "$tag: [join [lsort -unique $broken($tag)] { }]"
  }
  set ::exit_status 1
} elseif {$::errorCountTotal == 0} {
  puts "Preserving collected link data for incremental builds."
  keep_links_fileinfo db
  set ::exit_status 0
} else {
  set ::exit_status 1
}

db eval COMMIT

puts "Writing 4 link arrays to 'doc_vardump.txt'"
set fd [open [file join $::DOC doc_vardump.txt] wb]
foreach a {::glink ::llink} { dump_ow_links $a $fd }
foreach a {::backlink ::pagelink} { dump_ap_links $a $fd }
close $fd

if {$::doc_build_stats>0} { report_inc_stats db }
if {$::updating} {
  close $::pgfd
  clear_db_partial db
  puts \
"Tables link, keyword, fragment, page, alttitle and expage emptied or dropped.
Do a full docs build, target \"fast\", for requirements, evidence and etc."
}

db close

# Iff errors accumulated, blat them.
dump_errors stderr
# Finally, show bottom-line result summary.
set out_istty [expr 1 - [catch {chan configure stdout -mode}]]
foreach {aer aeg aet} [lmap ec {"1;31;40" "1;32;40" "0"} {
  string repeat "\u001B\[${ec}m" $out_istty
}] break

if {$::errorCountTotal == 0} {
  puts "Page ${aeg}processing succeeded${aet} with no errors."
} else {
  puts "Page ${aer}processing failed with $::errorCountTotal errors${aet}."
}

exit $::exit_status
