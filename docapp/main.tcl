eval [db one {SELECT sqlar_uncompress(data,sz) FROM sqlar
               WHERE name='wapp.tcl'}]
proc wapp-default {} {
  global wapp
  set x [string trimleft [dict get $wapp PATH_INFO] /]
  if {$x==""} {set x index.html}
  set doc [db one {SELECT sqlar_uncompress(data,sz)
                   FROM sqlar WHERE name=('doc/' || $x)}]
  if {$doc==""} {
    wapp-subst {<h1>Not Found: %html(/$x)</h1>}
    return
  }
  dict set wapp .reply $doc
  switch -glob -- $x {
    *.html {wapp-mimetype text/html}
    *.gif {wapp-mimetype image/gif}
    *.jpg {wapp-mimetype image/jpeg}
    *.png {wapp-mimetype image/png}
    *.css {wapp-mimetype text/css}
    default {wapp-mimetype text/html}
  }
}
if {[regexp {^-?-h(elp)?$} [lindex $argv 0]]} {
  puts [wapp-help]
  exit
}
wapp-start $argv
