#!/usr/bin/wapptclsh
#
# This is a Wapp[1] script that implements a release-checklist web application
# using the Fossil CGI extension mechanism[2].
#
# Installation instructions:
#
#    1.  Put the wapptclsh binary in /usr/bin.  (Or put it somewhere else
#        and edit the #! on the first line of this script.)
#
#    2.  Activate the CGI extension mechanism of Fossil.  Instructions
#        on how to do that are found at [2].  Add this script to the
#        extroot directory that you create as part of the activation
#        process.
#
#    3.  Create a directory in which to store checklist database files.
#        Edit this script to make the DATADIR variable hold the name
#        of that directory.  (The default name is "/checklist".  The
#        default name is a top-level directory in the filesystem because
#        in the canonical use case for this application, the Fossil
#        server is running inside a chroot jail.)
#
#           vvvvvvvvvv---  This is what you might need to edit
set DATADIR /checklist
#
#    4.  Add a prototype checklist database to DATADIR.  Perhaps use [3]
#        as the prototype.  Name the checklist database something that matches
#        the pattern "3*.db".
#
# To add a new checklist in the catalog:
#
#    1.  Copy an existing checklist database in the DATADIR directory
#        into the new filename.  Remember that checklist filenames should
#        follow the pattern "3*.db"
#
#    2.  Use the SQLite command-line utility program or the "SQL" option
#        in the checklist application to make the following SQL changes in
#        the new database:
#
#           a.  UPDATE config SET value='<Checklist-Name>' WHERE name='title';
#           b.  DELETE FROM history;
#           c.  DELETE FROM ckitem;
#
#        In step 2a, use an appropriate name for the checklist in place of
#        <Checklist-Name>, obviously.
#
# Links:
#
# [1] https://wapp.tcl.tk/
# [2] https://fossil-scm.org/home/doc/trunk/www/serverext.wiki
# [3] https://sqlite.org/docsrc/file/misc/checklist-prototype.db
#
package require wapp

# Any unknown URL dispatches to this routine.  List all available
# checklists.
#
proc wapp-default {} {
  wapp-page-listing
}

# List all available checklists.
#
proc wapp-page-listing {} {
  global DATADIR
  wapp-trim {
    <div class='fossil-doc' data-title='Available Checklists'>
  }
  wapp-subst {<div><ol style='column-width: 20ex;'>\n}
  foreach dbfile [lsort -decreasing [glob -nocomplain $DATADIR/*.db]] {
    set name [file rootname [file tail $dbfile]]
    set url [wapp-param BASE_URL]/$name/index
    wapp-subst {<li><a href='%url($url)'>%html($name)</a>\n}
  }
  wapp-subst {</ol></div>\n</html>\n}
}

# Show the CGI environment for testing purposes.
#
proc wapp-page-env {} {
  checklist-common-header
  sqlite3 db :memory:
  set v [db one {SELECT sqlite_source_id()}]
  wapp-trim {
     <div class='fossil-doc' data-title='Checklist Environment'>
     <pre>%html([wapp-debug-env])}
  wapp-subst {SQLite = %html($v)</pre>\n</div>\n}
  checklist-common-footer
}

# Show the complete text of this script.
#
proc wapp-page-self {} {
  wapp-cache-control max-age=3600
  checklist-common-header
  set fd [open [wapp-param SCRIPT_FILENAME] rb]
  set script [read $fd]
  close $fd
  wapp-trim {
    <p>The following is the complete text of the 
    <a href='https://wapp.tcl.tk/'>Wapp script</a> that implements this
    <a href='https://fossil-scm.org/home/doc/trunk/www/serverext.wiki'>Fossil
    CGI extension</a>:</p>
    <pre>%html($script)</pre>
  }
  checklist-common-footer
}


# Check user permissions provided to use by Fossil in the FOSSIL_USER
# and FOSSIL_CAPABILITIES environment variables.  Set the Wapp parameters
# as follows:
#
#     CKLIST_USER      Name of the user.  Empty string if not logged in
#     CKLIST_WRITE     True if the user is allowed to make updates
#     CKLIST_ADMIN     True if the user is an administrator.
#
# The database should already be open.
#
proc checklist-verify-login {} {
  global env
  set usr [wapp-param FOSSIL_USER]
  wapp-set-param CKLIST_USER $usr
  if {$usr!=""} wapp-allow-xorigin-params
  set perm [wapp-param FOSSIL_CAPABILITIES]
  wapp-set-param CKLIST_WRITE [string match {*i*} $perm]
  wapp-set-param CKLIST_ADMIN [string match {*[as]*} $perm]
}

# Print the common header shown on most pages
#
# Return 1 to abort.  Return 0 to continue with page generation.
#
proc checklist-common-header {} {
  if {![wapp-param-exists OBJECT] || [set dbfile [wapp-param OBJECT]]==""} {
    wapp-redirect listing
    return 1
  }
  sqlite3 db $dbfile -create 0
  db timeout 1000
  db eval BEGIN
  set title [db one {SELECT value FROM config WHERE name='title'}]
  wapp-trim {
    <div class='fossil-doc' data-title='%html($title)'>
    <style>
    div.ckcom {
      font-size: 80%;
      font-style: italic;
      white-space: pre;
    }
    span.ckuid {
      font-size: 80%;
      cursor: pointer;
    }
    p.error {
      font-weight: bold;
      color: red;
    }
    #editBox {
      display: none;
      border: 1px solid black;
    }
    </style>
  }
  checklist-verify-login
  wapp-subst {<div class="submenu">\n}
  set base [wapp-param BASE]
  set this [wapp-param PATH_HEAD]
  wapp-subst {<a href='%html($base/index)'>Checklist</a>\n}
  set dir [wapp-param ROOT_URL]
  wapp-subst {<a href='%html($dir/listing)'>Catalog</a>\n}
  set admin [wapp-param CKLIST_ADMIN 0]
  if {$admin} {
    if {$this!="cklistedit"} {
      wapp-subst {<a href='%html($base/cklistedit)'>Edit-checklist</a>\n}
    }
    if {$this!="sql"} {
      wapp-subst {<a href='%html($base/sql)'>SQL</a>\n}
    }
    wapp-subst {<a href='%html($base/env)'>CGI-environment</a>}
    wapp-subst {<a href='%html($base/self)'>Source-code</a>}
  }
  wapp-subst {</div>\n}
  return 0
}

# Close out a web page.  Close the database connection that was opened
# by checklist-common-header.
#
proc checklist-common-footer {} {
  wapp-subst {</div>}
  catch {db close}
}

# Show the main checklist page
#
proc wapp-page-index {} {
  if {[checklist-common-header]} return
  set level 0
  set v1 0
  set v2 0
  db eval {SELECT seq, printf('%016llx',itemid) AS itemid, txt
           FROM checklist ORDER BY seq} {
    if {$seq%100==0} {
      set newlevel 1
      incr v1
      set v2 0
      set v $v1
    } else {
      set newlevel 2
      incr v2
      set v $v2
    }
    while {$newlevel>$level} {
      if {$level==0} {
        wapp-subst {<ol id="mainCklist" type='1'>\n}
      } else {
        wapp-subst {<p><ol type='a'>\n}
      }
      incr level
    }
    while {$newlevel<$level} {
      wapp-subst {</ol>\n}
      incr level -1
    }
    if {$level==1} {wapp-subst {<p>}}
    wapp-trim {
      <li class='ckitem' id='item-%unsafe($itemid)' value='%html($v)'>
      <span>%unsafe($txt)</span>
      <span class='ckuid' id='stat-%unsafe($itemid)'></span>
      <div class='ckcom' id='com-%unsafe($itemid)'></div></li>\n
    }
  }
  while {$level>0} {
    wapp-subst {</ol>\n}
    incr level -1
  }

  # Render the edit dialog box. CSS sets "display: none;" on this so that
  # it does not appear.  Javascript will turn it on and position it on
  # the correct element following any click on the checklist.
  #
  if {![wapp-param WRITE 0]} {
    wapp-trim {
      <div id="editBox">
      <form id="editForm" method="POST">
      <table border="0">
      <tr>
      <td align="right">Status:&nbsp;
      <td><select id="editStatus" name="stat" size="1">
      <option value="ok">ok</option>
      <option value="prelim">prelim</option>
      <option value="fail">fail</option>
      <option value="review">review</option>
      <option value="pending">pending</option>
      <option value="retest">retest</option>
      <option value="---">---</option>
      </select>
      <tr>
      <td align="right" valign="top">Comments:&nbsp;
      <td><textarea id="editCom" name="com" cols="80" rows="2"></textarea>
      <tr>
      <td>
      <td><button id="applyBtn">Apply</button>
      <button id="cancelBtn">Cancel</button>
      </table>
      </form>
      </div>
    }
  }
    
  # The cklistUser object is JSON that contains information about the
  # login user and the capabilities of the login user, which the
  # javascript code needs to know in order to activate various features.
  #
  wapp-subst {<script id='cklistUser' type='application/json'>}
  if {![wapp-param CKLIST_WRITE]} {
    wapp-subst {{"user":"","canWrite":0,"isAdmin":0}}
  } else {
    set u [wapp-param CKLIST_USER]
    set ia [wapp-param CKLIST_ADMIN]
    wapp-subst {{"user":"%string($u)","canWrite":1,"isAdmin":%qp($ia)}}
  }
  wapp-subst {</script>\n}
  set base [wapp-param BASE]
  wapp-subst {<script src='%html($base/cklist.js)'></script>\n}
  checklist-common-footer
}

# The javascript for the main checklist page goes here
#
proc wapp-page-cklist.js {} {
  wapp-mimetype text/javascript
  wapp-cache-control max-age=86400
  set base [wapp-param BASE]
  wapp-trim {
    function cklistAjax(uri,data,callback){
      var xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function(){
        if(xhttp.readyState!=4) return
        if(!xhttp.responseText) return
        var jx = JSON.parse(xhttp.responseText);
        callback(jx);
      }
      if(data){
        xhttp.open("POST",uri,true);
        xhttp.setRequestHeader("Content-Type",
                               "application/x-www-form-urlencoded");
        xhttp.send(data)
      }else{
        xhttp.open("GET",uri,true);
        xhttp.send();
      }
    }
    function cklistClr(stat){
      stat = stat.replace(/\\++/g,'');
      if(stat=="ok") return '#00a000';
      if(stat=="prelim") return '#0080ff';
      if(stat=="fail") return '#a00028';
      if(stat=="review") return '#007088';
      if(stat=="pending") return '#4f0080';
      if(stat=="retest") return '#904800';
      return '#000000';
    }
    function cklistApplyJstat(jx){
      var i;
      var n = jx.length;
      for(i=0; i<n; i++){
        var x = jx[i];
        var name = "item-"+x.itemid
        var e = document.getElementById(name);
        if(!e) continue
        e.style.color = cklistClr(x.status);
        e = document.getElementById("stat-"+x.itemid);
        if(!e) continue;
        var s = "(" + x.status + " " + x.owner
        if( x.chngcnt>1 ){
          s += " " + x.chngcnt + "x)"
        }else{
          s += ")"
        }
        e.innerHTML = s
        if( x.comment && x.comment.length>0 ){
          e = document.getElementById("com-"+x.itemid);
          e.innerHTML = x.comment;
        }
        if( editItem && editItem.id==name ){
          document.getElementById("editStatus").value = x.status;
          document.getElementById("editCom").value = x.comment;
        }
      }
    }
    function clearEditBox(){
      document.getElementById("editStatus").value = 'ok';
      document.getElementById("editCom").value = '';
    }
    cklistAjax("%string($base/jstat)",null,cklistApplyJstat);
    var userNode = document.getElementById("cklistUser");
    var userInfo = JSON.parse(userNode.textContent||userNode.innerText);
    if(userInfo.canWrite){
      var allItem = document.getElementsByClassName("ckitem");
      for(var i=0; i<allItem.length; i++){
        allItem[i].style.cursor = "pointer";
      }
    }
    function historyOff(itemid){ 
      var e = document.getElementById("hist-"+itemid);
      if(e) e.parentNode.removeChild(e);
    }
    function historyOn(itemid){
      var req = new XMLHttpRequest
      req.open("GET","%string($base)/history?itemid="+itemid,true);
      req.onreadystatechange = function(){
        if(req.readyState!=4) return
        var lx = document.getElementById("item-"+itemid);
        var tx = document.createElement("DIV");
        tx.id = "hist-"+itemid;
        tx.style.borderWidth = 1
        tx.style.borderColor = "black"
        tx.style.borderStyle = "solid"
        tx.innerHTML = req.responseText;
        lx.appendChild(tx);
      }
      req.send();
    }
    var editItem = null
    var editBox = document.getElementById("editBox");
    document.getElementById("mainCklist").onclick = function(event){
      var e = document.elementFromPoint(event.clientX,event.clientY);
      while(e && e.tagName!="LI"){
        if(e.id){
          if(e.id=="editForm") return;
          if(e.id.substr(0,5)=="stat-"){
            var id = e.id.substr(5);
            if( document.getElementById("hist-"+id) ){
              historyOff(id)
            }else{
              historyOn(id)
            }
            return;
          }
        }
        if(e==editBox) return;
        e = e.parentNode;
      }
      if(!userInfo.canWrite) return
      if(!e) return
      if(editItem) editItem.removeChild(editBox);
      if(e==editItem){
        editItem = null;
        return;
      }
      editBox.style.display = "block";
      editItem = e;
      historyOff(e.id.substr(5))
      editItem.appendChild(editBox);
      clearEditBox();
      var u = "%string($base)/jstat?itemid=" + e.id.substr(5);
      cklistAjax(u,null,cklistApplyJstat);
      document.getElementById("cancelBtn").onclick = function(event){
        event.stopPropagation();
        editItem.removeChild(editBox);
        editItem = null;
      }
      document.getElementById("applyBtn").onclick = function(event){
        var data = "update=" + editItem.id.substr(5);
        var e = document.getElementById("editStatus");
        data += "&status=" + escape(e.value);
        e = document.getElementById("editCom");
        data += "&comment=" + escape(e.value);
        cklistAjax("%string($base)/jstat",data,cklistApplyJstat);
        editItem.removeChild(editBox);
        editItem = null;
        event.stopPropagation();
      }
      document.getElementById("editForm").onsubmit = function(){
        return false;
      }
    }
  }
  # wapp-subst {window.alert("Javascript loaded");\n}
}

# The /jstat page returns JSON that describes the current
# status of all elements of the checklist.
#
# If the update query parameter exists and is not an empty string,
# and if the login is valid for a writer, then revise
# the ckitem entry where itemid=$update using query parameters
# {update->itemid,status,comment} and with owner set to the login user,
# before returning the results.
#
# If the itemid query parameter exists and is not an empty string,
# then return only the status to that one checklist item.  Otherwise,
# return the status of all checklist items.
#
# The update and itemid parameters come in as hex.  They must be
# converted to decimal before being used for queries.
#
proc wapp-page-jstat {} {
  if {![wapp-param-exists OBJECT] || [set dbfile [wapp-param OBJECT]]==""} {
    wapp-redirect listing
    return
  }
  wapp-mimetype text/json
  sqlite3 db $dbfile
  db eval BEGIN
  set update [wapp-param update]
  if {$update!=""} {
    checklist-verify-login
    if {[wapp-param CKLIST_WRITE 0] && [scan $update %x update]==1} {
      set status [wapp-param status]
      set comment [string trim [wapp-param comment]]
      set owner [wapp-param CKLIST_USER]
      db eval {
         REPLACE INTO ckitem(itemid,mtime,status,owner,comment)
          VALUES($update,julianday('now'),$status,$owner,$comment);
         INSERT INTO history(itemid,mtime,status,owner,comment)
          VALUES($update,julianday('now'),$status,$owner,$comment);
      }
    }
  }
  set itemid [wapp-param itemid]
  if {$itemid!="" && [scan $itemid %x itemid]==1} {
    set sql {
      SELECT json_group_array(
        json_object('itemid', printf('%016llx',itemid),
                    'mtime', strftime('%s',mtime)+0,
                    'status', rtrim(status,'+'),
                    'owner', owner,
                    'comment', comment,
                    'chngcnt', (SELECT count(*) FROM history
                                WHERE itemid=$itemid)))
      FROM ckitem WHERE itemid=$itemid
    }
  } else {
    set sql {
      WITH chngcnt(cnt,itemid) AS (
         SELECT count(*), itemid FROM history GROUP BY itemid
      )
      SELECT json_group_array(
        json_object('itemid', printf('%016llx',itemid),
                    'mtime', strftime('%s',mtime)+0,
                    'status', rtrim(status,'+'),
                    'owner', owner,
                    'comment', comment,
                    'chngcnt', COALESCE(chngcnt.cnt,0))
        )
        FROM ckitem LEFT JOIN chngcnt USING(itemid)
    }
  }
  wapp-unsafe [db one $sql]
  db eval COMMIT
  db close
  # puts "jstat from $dbfile"
}

# The /history page returns an HTML table that shows the history of
# changes to a single checklist item.
#
#
proc wapp-page-history {} {
  set dbfile [wapp-param OBJECT]
  set itemid [wapp-param itemid]
  if {$dbfile=="" || $itemid=="" || [scan $itemid %x itemid]!=1} return
  wapp-mimetype text/text
  sqlite3 db $dbfile
  db eval BEGIN
  wapp-subst {<table border="0" cellspacing="4">\n}
  set date {}
  db eval {SELECT date(mtime) as dx, strftime('%H:%M',mtime) as tx,
                  owner, rtrim(status,'+') AS status, comment FROM history
                  WHERE itemid=$itemid
                  ORDER BY julianday(mtime) DESC} {
     if {$dx!=$date} {
       wapp-subst {<tr><td>%html($dx)<td><td>\n}
       set date $dx
     }
     wapp-trim {
        <tr><td align="right" valign="top">%html($tx)
            <td valign="top">%html($status) %html($owner)
            <td>%html($comment)</tr>\n
     }
  }
  wapp-subst {</table>\n}
}


# The /sql page for doing arbitrary SQL on the database.
# This page is accessible to the administrator only.
#
proc wapp-page-sql {} {
  if {[checklist-common-header]} return
  if {![wapp-param CKLIST_ADMIN 0]} {
    wapp-redirect index
    return
  }
  set sql [string trimright [wapp-param sql]]
  wapp-trim {
    <form method="POST"><table border="0">
    <tr><td valign="top">SQL:&nbsp;
    <td><textarea name="sql" rows="5" cols="60">%html($sql)</textarea>
    <tr><td><td><input type="submit" value="Run">
    </table></form>
  }
  if {$sql!=""} { 
    set i 0
    wapp-subst {<hr><table border="1">\n}
    set rc [catch {
      db eval $sql x {
        if {$i==0} {
          wapp-subst {<tr>\n}
          foreach c $x(*) {
            wapp-subst {<th>%html($c)\n}
          }
          wapp-subst {</tr>\n}
          incr i
        }
        wapp-subst {<tr>\n}
        foreach c $x(*) {
          set v [set x($c)]
          wapp-subst {<td>%html($v)\n}
        }
        wapp-subst {</tr>}
      }
    } msg]
    if {$rc} {
      wapp-subst {<tr><td>ERROR: %html($msg)\n}
    }
    wapp-subst {</table>}
  }
  db eval COMMIT
  checklist-common-footer 
}

# Generate a text encoding of the checklist table
#
#    # (hash) top level item
#    ## (hash) second-level item
#    ## (hash) another second-level
#    # (hash) another top-level
#
proc checklist-as-text {} {
  set out {}
  db eval {SELECT seq, itemid, txt FROM checklist ORDER BY seq} {
    set id [format %x $itemid]
    regsub -all {\s+} [string trim $txt] { } txt
    if {($seq%100)==0} {
      append out "# ($id) $txt\n"
    } else {
      append out "## ($id) $txt\n"
    }
  }
  return $out
}

# Replace the content of the checklist table with a decoding
# of the text string given in the argument.  Throw an error and
# rollback the change if anything doesn't look right.
#
proc checklist-rebuild-from-text {txt} {
  set re {^(\#\#?) (\([0-9a-fA-F]+\) )?(.+)$}
  db transaction {
    db eval {DELETE FROM checklist}
    set i 0
    foreach line [split $txt \n] {
      set line [string trimright $line]
      if {$line==""} continue
      if {[regexp $re $line all a h t]} {
        if {$h==""} {unset h} {scan $h (%x) h}
        if {$a=="#"} {
          set i [expr {(int($i/100)+1)*100}]
        } elseif {$a=="##"} {
          if {$i==0} {error "\"##\" before any \"#\""}
          incr i
        } else {
          error "unknown line prefix: \"$a\""
        }
        db eval {INSERT INTO checklist(seq,itemid,txt)
                 VALUES($i,COALESCE($h,abs(random())),$t)}
      } else {
        error "illegal checklist line: \"$line\""
      }
    }
  }
}

# The /cklistedit page allows the administrator to edit the items on
# the checklist.
#
proc wapp-page-cklistedit {} {
  if {[checklist-common-header]} return
  if {![wapp-param CKLIST_ADMIN 0]} {
    wapp-redirect index
    return
  }
  set cklist [string trim [wapp-param cklist]]
  if {$cklist!=""} {
    checklist-rebuild-from-text $cklist
  }
  set x [checklist-as-text]
  wapp-trim {
    <form method="POST">
    <p>Edit checklist: <input type="submit" value="Install"><br>
    <textarea name="cklist" rows="40" cols="120">%html($x)</textarea>
    <br><input type="submit" value="Install">
    </form>
    </p>
  }
  catch {db eval COMMIT}
  checklist-common-footer 
}

# This dispatch hook checks to see if the first element of the PATH_INFO
# is the name of a checklist database.  If it is, it makes that database
# the OBJECT and shifts a new method name out of PATH_INFO and into
# PATH_HEAD for dispatch.
#
# If the first element of PATH_INFO is not a valid checklist database name,
# then change PATH_HEAD to be the database listing method.
#
proc wapp-before-dispatch-hook {} {
  global DATADIR
  set dbname [wapp-param PATH_HEAD]
  if {$dbname=="top"} {
    set filelist [glob -tails -directory $DATADIR 3*.db]
    set dbname [lindex [lsort -decr $filelist] 0]
    regsub {.db$} $dbname {} dbname
  }
  wapp-set-param ROOT_URL [wapp-param BASE_URL]
  if {[file readable $DATADIR/$dbname.db]} {
    # an appropriate database has been found
    wapp-set-param OBJECT $DATADIR/$dbname.db
    if {[regexp {^([^/]+)(.*)$} [wapp-param PATH_TAIL] all head tail]} {
      wapp-set-param PATH_HEAD $head
      wapp-set-param PATH_TAIL [string trimleft $tail /]
      wapp-set-param SELF_URL /$head
    } else {
      wapp-set-param PATH_HEAD {}
      wapp-set-param PATH_TAIL {}
    }
    wapp-set-param BASE [wapp-param BASE_URL]/$dbname
  } else {
    # Not a valid database.  Change the method to list all available
    # databases.
    wapp-set-param OBJECT {}
    wapp-set-param BASE [wapp-param SCRIPT_NAME]
    if {$dbname!="env" && $dbname!="self"} {
      wapp-set-param PATH_HEAD listing
    }
  }
}

# Start up the web-server
wapp-start $::argv
