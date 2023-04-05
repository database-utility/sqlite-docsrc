#!/usr/bin/wapptclsh
#
package require wapp
if {![info exists env(FOSSIL_URI)]} {
  error "This script must be run as a Fossil CGI extension"
}
proc open-database {} {
  set self [wapp-param SCRIPT_FILENAME]
  set dir [file dir $self]
  set dbname [file dir $self]/-[file rootname [file tail $self]].db
  sqlite3 db $dbname
  db eval {
    CREATE TABLE IF NOT EXISTS outcome(
      testId TEXT PRIMARY KEY, -- large random hex key
      platformId TEXT,         -- references platform
      testName TEXT,           -- ex: th3.t05, releasetest.default
      status TEXT,             -- "pass", "fail", "running"
      mtime INT,               -- When this record received, seconds since 1970
      ipaddr TEXT,             -- received from this IP address
      elapsetm INT,            -- Time test took to run, seconds
      srchash TEXT,            -- SQLite source_id()
      srcdate TEXT,            -- SQLite version date, ISO8601
      toolhash TEXT,           -- Test script source_id()
      tooldate TEXT,           -- Test script version date, ISO8610
      expiretm INT,            -- When this record expires, seconds since 1970
      branch TEXT,             -- Branch name for SQLite code
      report TEXT,             -- Final test result text (maybe NULL)
      testcase BLOB            -- Testcase (probably NULL except failures)
    );
    CREATE TABLE IF NOT EXISTS platform(
      platformId TEXT PRIMARY KEY, -- large random hex key
      mtime INT,                   -- time of last change, sec since 1970
      ipaddr TEXT,                 -- IP address of last change
      name TEXT UNIQUE,            -- Short name
      ostype TEXT,                 -- 'linux','windows','mac','sparc'
      os TEXT,                     -- ex: 'Ubuntu 18.04', 'Windows 10'
      owner TEXT,                  -- ex: 'drh'
      location TEXT,               -- ex: 'Charlotte, NC'
      description TEXT             -- ex: 'Yoga laptop'
    );
  }
  db timeout 5000
}
proc common-header {{title {Test Dashboard}} {exlist {}} {newlist {}}} {
  wapp-trim {
     <div class='fossil-doc' data-title='%html($title)'>
     <div class='submenu'>
  }
  set base [wapp-param BASE_URL]
  set sub(Outcomes) olist
  set sub(Platforms) plist
  foreach {name link} $newlist {set sub($name) $link}
  foreach name [lsort [array names sub]] {
    set link $sub($name)
    if {$link ni $exlist} {
      wapp-trim {
        <a class='label' href='%unsafe($base/$link)'>%html($name)</a>
      }
    }
  }
  wapp-subst {</div>\n}
}
proc common-footer {} {
  wapp-subst {</div>\n}
}
proc wapp-page-env {} {
  wapp-allow-xorigin-params
  common-header {Wapp Environment}
  foreach key [array names ::env FOSSIL_*] {
    wapp-set-param $key $::env($key)
  }
  wapp-trim {<pre>%html([wapp-debug-env])</pre>}
  common-footer
}

# Show a list of test outcomes
#
proc wapp-page-olist {} {
  open-database
  common-header "Test Outcomes" olist
  set now [db one {SELECT datetime('now')}]
  wapp-trim {
    <p>Test Outcomes As Of %html($now)</p>
  }
  wapp-subst {<ul>\n}
  set last_srchash {}
  set last_platform {}
  set case_close {}
  set platform_close {}
  db eval {SELECT status, testName, platform.name AS pname, srchash, srcdate,
                  datetime(srcdate) AS sdate,
                  datetime(max(outcome.mtime),'unixepoch') AS odate, report
             FROM outcome, platform
            WHERE outcome.mtime>CAST(strftime('%s','now','-1 month') AS INT)
              AND platform.platformId=outcome.platformId
              AND (status<>'running' OR
                   outcome.mtime>CAST(strftime('%s','now','-4 hours') AS INT))
            GROUP BY testName, srchash, outcome.platformId
           ORDER BY srcdate DESC, pname, outcome.mtime DESC, status DESC} {
     if {$srchash!=$last_srchash} {
       wapp-trim {
         %unsafe($case_close)
         %unsafe($platform_close)
         <li><a href='https://sqlite.org/src/timeline?c=%html($srchash)'>
         %html%($sdate)% %html%([string range $srchash 0 16])%</a>
         <ol type='A'>
       }
       set case_close {}
       set platform_close </ol></li>
       set last_srchash $srchash
       set last_platform {}
     }
     if {$pname!=$last_platform} {
       wapp-trim {
         %unsafe($case_close)
         <li>%html($pname)
         <ol type='1'>
       }
       set case_close </ol></li>
       set platform_close </ol></li>
       set last_platform $pname
     }
     set clr black
     switch $status {
       fail {set clr red}
       running {set clr gray}
       ok -
       pass {set clr green}
     }
     wapp-trim {
       <li><span style='color:%html($clr);'>
       <b>%html($status)</b> - %html($testName)
       <small>(%html($odate))
     }
     if {[string length $report]} {
       wapp-trim {- %html($report)}
     }
     wapp-trim {</small></span></li>}
  }
  wapp-trim {
    %unsafe($case_close)
    %unsafe($platform_close)
    </ul>
  }
  wapp-trim {
    <script nonce='%html([wapp-param FOSSIL_NONCE])'>
      setTimeout(function(){location.reload();},1000*60);
    </script>
  }
  common-footer
}

# Make sure the Fossil user has the listed capability.
# Return 0 on success.  If the capability is missing,
# redirect to the login page and return 1.
#
proc check-capability {cap} {
  if {[string match *${cap}* $::env(FOSSIL_CAPABILITIES)]} {
    return 0
  }
  wapp-redirect $::env(FOSSIL_URI)/login?g=[wapp-param REQUEST_URI]
  return 1
}

# List all available platforms
#
proc wapp-page-plist {} {
  if {[check-capability i]} return
  common-header "Test Platforms" plist {{New Platform} padd}
  wapp-trim {
    <table class='sortable' border='1' cellspacing='0' cellpadding='2'\
     data-column-types='ttttx' data-init-sort='1'>
    <thead><tr>
      <th>Name
      <th>OS-Type
      <th>Owner
      <th>Description
      <th>&nbsp;
    </tr></thead>
    <tbody>
  }
  set base [wapp-param BASE_URL]
  open-database
  db eval {SELECT name, ostype, owner, description, rowid
             FROM platform ORDER BY 1} {
    wapp-trim {
      <tr>
      <td>%html($name)
      <td>%html($ostype)
      <td>%html($owner)
      <td>%html($description)
      <td><a href="%html($base)/pdetail/%html($rowid)">Details</a>
      </tr>
    }
  }
  wapp-trim {
    </tbody>
    </table>
    <script src='%url([wapp-param FOSSIL_URI])/builtin/sorttable.js'></script>
  }
  common-footer
}

# Show the details of a single platform entry
#
proc wapp-page-pdetail {} {
  if {[check-capability i]} return
  set id 0
  scan [wapp-param PATH_TAIL] %d id
  open-database
  set seen 0
  db eval {SELECT *, datetime(mtime,'unixepoch') AS ctime
           FROM platform WHERE rowid=$id} {set seen 1; break}
  if {!$seen} {
    common-header "Platform Not Found"
    wapp-subst {<h1>No such platform: %html($id)</h1>\n}
    common-footer
    return
  }
  common-header "Details For Platform $name"
  set u [wapp-param BASE_URL]
  wapp-trim {
    <table class="label-value">
    <tr><th>Name:</td><td>%html($name)</td>
    <tr><th>OS-Type:</td><td>%html($ostype)</td>
    <tr><th>OS:</td><td>%html($os)</td>
    <tr><th>Location:</td><td>%html($location)</td>
    <tr><th>Description:</td><td>%html($description)</td>
    <tr><th>Owner:</td><td>%html($owner)</td>
    <tr><th>Date:</td><td>%html($ctime)</td>
    <tr><th><tt>dashconfig</tt>:</td><td>%html($u $platformId)</td>
    <table>
  }
  common-footer
}

# Add a new platform entry
#
proc wapp-page-padd {} {
  if {[check-capability i]} return
  open-database
  set nm [wapp-param nm]
  set ostype [wapp-param ostype linux]
  set os [wapp-param os]
  set ds [wapp-param ds]
  set loc [wapp-param loc]
  common-header "Define A New Platform"
  if {$nm!=""} {
    db eval BEGIN
    if {[db exists {SELECT 1 FROM platform WHERE name=$nm}]} {
      wapp-trim {
        <p class='generalError'>
        The platform name "%html($nm)" is already used.  Choose another.
        </p>
      }
    } else {
      set ipaddr [wapp-param REMOTE_ADDR]
      set owner [wapp-param FOSSIL_USER]
      db eval {
        INSERT INTO platform(platformId,mtime,ipaddr,name,ostype,
                             os,owner,location,description)
        VALUES(lower(hex(randomblob(20))),strftime('%s','now'),
               $ipaddr,$nm,$ostype,$os,$owner,$loc,$ds)
      }
      set redir [wapp-param BASE_URL]/pdetail/[db last_insert_rowid]
      db eval COMMIT
      db close
      wapp-redirect $redir
      return
    }
    db eval COMMIT
    db close
  }
  wapp-trim {
    <form method="POST">
    <table class="label-value">
    <tr><th>Name:</th>
    <td><input type='text' size='15' name='nm' value='%html($nm)'></td></tr>
    <tr><th>Class:</th>
    <td><select name='ostype' size='1'>
  }
  foreach x {linux mac windows other} {
    wapp-subst {<option value='%html($x)'}
    if {$x==$ostype} {
      wapp-subst { selected='selected'}
    }
    wapp-subst {>%html($x)</option>\n}
  }
  wapp-trim {
    <tr><th>OS:</th>
    <td><input type='text size='20' name='os' value='%html($os)'></td></tr>
    <tr><th>Location:</th>
    <td><input type='text size='40' name='loc' value='%html($loc)'></td></tr>
    <tr><th>Description:</th>
    <td><input type='text size='40' name='ds' value='%html($ds)'></td></tr>
    <tr><th></th><td><input type='submit' value='Create'></td></tr>
    </table>
    </form>
  }
  common-footer
}

set UPLOAD_DEBUG 1

# Report an upload failure
#
proc upload-failure {code reason} {
  global UPLOAD_DEBUG
  if {$UPLOAD_DEBUG} {
    puts stderr "***** upload failed: $reason"
  }
  wapp-reply-code $code
  wapp-mimetype text/plain
  wapp-subst {%unsafe($reason)}
}

# Receive an outcome upload
#
proc wapp-page-upload {} {
  global UPLOAD_DEBUG
  if {$UPLOAD_DEBUG} {
    puts stderr "****************** upload ************************"
    foreach key [lsort [wapp-param-list]] {
      if {[string index $key 0]=="."} continue
      if {$key=="CONTENT" 
          && [string match text/* [wapp-param CONTENT_TYPE]]==0} continue
      puts stderr "$key = [list [wapp-param $key]]"
    }
  }
  set rc [catch {wapp-page-upload-unsafe} msg]
  if {$rc && $UPLOAD_DEBUG} {
    puts stderr "ERROR: $msg"
  }
}
proc wapp-page-upload-unsafe {} {
  if {[wapp-param CONTENT_TYPE]!="application/x-sqlite"} {
    upload-failure 400 {wrong content type}
    return
  }
  sqlite3 memdb :memory:
  memdb deserialize [wapp-param CONTENT]
  if {[memdb one {PRAGMA quick_check}]!="ok"} {
    memdb close
    upload-failure 400 {corrupt payload}
    return
  }
  memdb eval {SELECT k, v FROM up} {
    set data($k) $v
  }
  memdb close
  foreach key {testId platformId testName status branch} {
    if {![info exists data($key)]} {
      upload-failure 400 "missing parameter: $key"
      return
    }
  }
  open-database
  if {![db exists {SELECT 1 FROM platform
                    WHERE platformId=$data(platformId)}]} {
    upload-failure 401 "unauthorized"
    return
  }
  set ipaddr [wapp-param REMOTE_ADDR]
  db eval {
    REPLACE INTO outcome(testId, platformId, testName, status,
                         mtime, ipaddr, elapsetm, srchash, srcdate,
                         toolhash, tooldate, expiretm, branch, report,
                         testcase)
    VALUES($data(testid),$data(platformId),$data(testName),$data(status),
           strftime('%s','now'),$ipaddr,$data(elapsetm),
           $data(srchash), $data(srcdate), $data(toolhash), $data(tooldate),
           strftime('%s','now')+$data(ttl), $data(branch), $data(report),
           $data(testcase));
  }
  db close
  wapp-mimetype text/plain
  wapp-subst {Ok}
}


proc wapp-default {} {
  wapp-page-olist
}
wapp-start {}
