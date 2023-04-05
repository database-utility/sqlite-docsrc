#
# This is TCL library for uploading a test outcome to the testing dashboard.
# Test scripts can "source" this library and then invoke its methods in order
# to report test success and/or failure to the dashboard.
#
# Requirements:
#
#    *  SQLite needs to be loaded into the TCL interpreter
#
#    *  A recent "fossil" command needs to be available to "exec".
#
#    *  A platform configuration file needs to be configured.  The
#       platform configuration is a file named "./dashconfig" or
#       "~/.dashconfig" (searched in that order) that is a single
#       line of two fields, the URL of the dashboard server and the
#       platform code.
#
# Usage:
#
# The test script must invoke "dashboard-init" exactly once in order
# to initialize the uplink library.
#
# Each test scenario run by the script must be given its own name.
# Call it $testName.  For each test scenario, the script must run:
#
#     dashboard-config $testName $key1 $value1 $key2 $value2 ...
#
# The dashboard-config command can be run multiple times.  Duplicate
# keys silently overwrite.  The following keys are supported:
#
#     srchash       (REQUIRED) The SHA3 hash of the SQLite version under test
#
#     srcdate       (REQUIRED) Dates of the SQLite version under test in the
#                   ISO8601 format:  "YYYY-MM-DD HH:MM:SS"
#
#     branch        (REQUIRED) The branch from which srchash is taken
#
#     toolhash      (optional) SHA3 hash of the system doing the testing
#
#     tooldate      (optional) ISO8601 date corresponding to toolhash
#
#     elapsetm      (optional) Number of seconds for which the test ran
#
#     expire        (optional) This report should expire after this many
#                   seconds.  Used for "running" reports to indicate that
#                   the script expects to update the report later.
#
#     report        (optional) Output from the test run.  This should be
#                   abbreviated to show the final test results, or perhaps
#                   some error diagnostics in the event of a failure.  While
#                   very large reports are accepted, it is best to keep them
#                   small by removing extraneous text prior to upload.
#
#     testcase      (optional) The testcase that provoked a failure in
#                   a fuzz-testing scenario
#
# Note in particular that srchash and srcdate must be set!
#
# After the scenario is configured, invoke one of the following to upload
# the report to the dashboard:
#
#     dashboard-running $testName
#     dashboard-pass $testName
#     dashboard-fail $testName
#
# The dashboard-running command can be invoked multiple times.  After
# dashboard-pass or dashboard-fail, however, the scenario is finish and
# cannot be reused without reconfiguring it from scratch.
#
proc dashboard-init {} {
  upvar #0 dashboard-global G
  set miss {}
  foreach x {./dashconfig ~/.dashconfig} {
    set x [file normalize $x]
    if {[file readable $x]} {
      set fd [open $x rb]
      foreach {url platformId} [read $fd] break
      close $fd
      break
    } else {
      lappend miss $x
    }
  }
  if {![info exists url]} {
    return "cannot find the dashboard upload configuration any of: $miss"
  }
  if {[catch {package require sqlite3}]} {
    return "cannot load the sqlite3 package"
  }
  set G(url) $url
  set G(platformId) $platformId
  set G(trace) 0
  package require sqlite3
  sqlite3 dashboard-db :memory:
  dashboard-db eval {PRAGMA page_size=512}
  dashboard-db eval {CREATE TABLE up(k,v)}
  return {}
}
proc dashboard-remote {} {
  upvar #0 dashboard-global G
  if {[info exists G(url)]} {return $G(url)}
  return {}
}
proc dashboard-uuid {} {
  return [dashboard-db eval {SELECT lower(hex(randomblob(20)))}]
}
proc dashboard-config {name args} {
  upvar #0 dashboard-data-$name D dashboard-global G
  if {![info exists G(url)]} return
  foreach {key value} $args {
    set D($key) $value
  }
  if {![info exists D(testId)]} {
    set D(testId) [dashboard-uuid]
  }
}
proc dashboard-unconfig {name} {
  upvar #0 dashboard-data-$name D
  unset -nocomplain D
}
proc dashboard-trace {bool} {
  upvar #0 dashboard-global G
  set G(trace) $bool
}
proc dashboard-send {name} {
  upvar #0 dashboard-data-$name D dashboard-global G
  if {![info exists G(url)]} return
  if {![info exists D]} {
    error "no such testcase: $name"
  }
  if {$G(trace)} {
    puts "DASHBOARD-TRACE: send $name"
  }
  dashboard-db eval {DELETE FROM up}
  set D(platformId) $G(platformId)
  set D(testName) $name
  foreach key [array names D] {
    set val $D($key)
    dashboard-db eval {INSERT INTO up VALUES($key,$val)}
  }
  set uid [dashboard-uuid]
  set fup dashboard-uplink-$uid.db
  set fdown dashboard-downlink-$uid.txt
  dashboard-db eval {VACUUM}
  dashboard-db backup $fup
  dashboard-db eval {DELETE FROM up}
  set cmd "exec fossil test-httpmsg $G(url)/upload $fup \
                  --mimetype application/x-sqlite >$fdown"
  set rc [catch $cmd msg]
  if {$G(trace)} {
    puts "DASHBOARD-TRACE: $cmd"
    if {$rc} {
      puts "DASHBOARD-TRACE: upload failed: $msg"
    }
  }
  if {$rc} {
    puts stderr "dashboard uplink to $G(url) failed"
    puts stderr "error-message: \"$msg\""
    puts stderr "uplink-command: $cmd"
  } else {
    file delete $fup
    file delete $fdown
  }
}
proc dashboard-running {name} {
  dashboard-config $name status running
  dashboard-send $name
}
proc dashboard-pass {name} {
  dashboard-config $name status pass
  dashboard-send $name
  dashboard-unconfig $name
}
proc dashboard-fail {name} {
  dashboard-config $name status fail
  dashboard-send $name
  dashboard-unconfig $name
}
