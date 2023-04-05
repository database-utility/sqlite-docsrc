

proc document_header {title path {search {}}} {
  set ret [subst -nocommands {
  <!DOCTYPE html>
  <html><head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="content-type" content="text/html; charset=UTF-8">
  <link href="${path}sqlite.css" rel="stylesheet">
  <title>$title</title>
  <!-- path=$path -->
  <link rel="stylesheet" href="${path}xcode-dark.css"/>
  <script src="${path}highlight.min.js"></script>
  
  <script>
      hljs.configure({ languages: ['c', 'sql', 'sqlite', 'json', 'ini', 'shell'] });

      document.addEventListener('DOMContentLoaded', function(event) {
          document.getElementsByClassName("nosearch")[0]?.nextElementSibling?.children[0]?.classList.add("language-c");
          document.querySelectorAll('pre').forEach(function(el) {
              hljs.highlightElement(el);
          });
      });
  </script>
  </head>
  }]

  if {[file exists DRAFT]} {
    set tagline {<font size="6" color="red">*** DRAFT ***</font>}
  } else {
    set tagline {Small. Fast. Reliable.<br>Choose any three.}
  }

  append ret [subst -nocommands {<body>}]

  append ret [subst -nocommands {
    <script>
      function toggle_div(nm) {
        var w = document.getElementById(nm);
        if( w.style.display=="block" ){
          w.style.display = "none";
        }else{
          w.style.display = "block";
        }
      }

      function toggle_search() {
        var w = document.getElementById("searchmenu");
        if( w.style.display=="block" ){
          w.style.display = "none";
        } else {
          w.style.display = "block";
          setTimeout(function(){
            document.getElementById("searchbox").focus()
          }, 30);
        }
      }

      function div_off(nm){document.getElementById(nm).style.display="none";}
      window.onbeforeunload = function(e){div_off("submenu");}

      /* Used by the Hide/Show button beside syntax diagrams, to toggle the */
      /* display of those diagrams on and off */
      function hideorshow(btn,obj){
        var x = document.getElementById(obj);
        var b = document.getElementById(btn);
        if( x.style.display!='none' ){
          x.style.display = 'none';
          b.innerHTML='show';
        }else{
          x.style.display = '';
          b.innerHTML='hide';
        }
        return false;
      }
    </script>
  }]

  regsub -all {\n+\s+} [string trim $ret] \n ret
  regsub -all {\s*/\*[- a-z0-9A-Z"*\n]+\*/} $ret {} ret
  return $ret
}
