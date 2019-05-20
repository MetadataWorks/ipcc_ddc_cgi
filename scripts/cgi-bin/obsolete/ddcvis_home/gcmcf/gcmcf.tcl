# gcmcf.tcl - DDCvis GCM Change Fields

source gcf_common.tcl

proc output_gif {filename} {
  fconfigure stdout -translation binary
  fconfigure stdout -encoding binary
  puts "Content-type: image/gif\n"
  set f [open $filename r]
  fconfigure $f -encoding binary
  fconfigure $f -translation binary
  puts -nonewline [read $f]
  close $f
}


proc unescape {text} {
  regsub -all {\+} $text " " text
  return $text
}


proc parse_form_input {} {
  global env Form
  if {[info exists env(CONTENT_LENGTH)]} {
    set text [read stdin]
    #puts "Content-type: text/plain\n"
    #puts $text
    foreach item [split $text &] {
      set a [split $item =]
      set Form([lindex $a 0]) [unescape [lindex $a 1]]
    }
  }
}


proc parse_query_string {} {
  global env Form
  if {[info exists env(QUERY_STRING)]} {
    set qs $env(QUERY_STRING)
    if {$qs!=""} {
      set a [split $env(QUERY_STRING) "_"]
      set Form(gcmscen) "[lindex $a 0]_[lindex $a 1]"
      set Form(var) [lindex $a 2]
    }
  }
}


proc onefield {name title values} {
  global Form
  set selected "(none)"
  if {[info exists Form($name)]} {
    set selected $Form($name)
  }
  puts "<tr><td align=\"right\"><b>$title:</b></td><td><select name=\"$name\">"
  foreach value $values {
    set mnem [lindex $value 0]
    set full [lindex $value 1]
    if {$full==""} {set full [join [split $mnem _] /]}
    set s ""
    if {$selected==$mnem} {
      set s " selected=1"
    }
    puts "<option value=\"$mnem\"$s>$full</option>"
  }
  puts "</select></td></tr>"
}


proc enumerate {items} {
  set n 1
  foreach item $items {
    lappend e [list $n $item]
    incr n
  }
  return $e
}


proc output_datasets_table {gcmscen var} {
  global env Form GcmScenarios Variables ReqURI
  puts "<table border=1><tr><td></td>"
  foreach vv $Variables {
    set v [lindex $vv 0]
    if {$v==$Form(var)} {
      set v "<b>$v</b>"
    }
    puts "<td>$v</td>"
  }
  puts "</tr>"
  foreach gg $GcmScenarios {
    set g [lindex $gg 1]
    if {[lindex $gg 0]==$gcmscen} {
      set g "<b>$g</b>"
    }
    puts "<tr align=\"center\"><td align=\"right\">$g</td>"
    set g [lindex $gg 0]
    foreach vv $Variables {
      set v [lindex $vv 0]
      if {[file exists cooked/${g}_${v}_2020.pgm]} {
        set cell "<a href=\"$ReqURI?${g}_${v}\">*</a>"
        if {$g==$gcmscen||$v==$Form(var)} {
          #set cell "<b>$cell</b>"
        }
      } else {
        set cell "&nbsp;"
      }
      puts "<td>$cell</td>"
    }
    puts "</tr>"
  }
  puts "</table>"
}


proc output_form {} {
  global env Form GcmScenarios Variables ReqURI
  puts "Content-type: text/html\n"
  puts "<html>"
  puts "  <head>"
  puts "    <title>New view GCM change fields</title>"
  puts "  </head>"
  puts "  <body>"
  puts "    <center>"
  puts "    <h1>SRES GCM change fields (IPCC 2001)</h1>"
  puts "    <p>View change in GCM fields relative to the 1961-1990 mean.  Three time periods are available: 2010-2039, 2040-2069 and 2070-2099."
  puts "    <form method=\"POST\" action=\"$ReqURI\">"
  puts "      <table border=0><tr valign=\"top\"><td>"
  puts "        <table border=0>"
      
  onefield var Variable $Variables
  
  onefield land "Map type" {
    {L "Land only"} 
    {B "Land + ocean"}
  }

  onefield gcmscen "GCM/Scenario" $GcmScenarios

  onefield decade "Time slice" {
    {2020 2020s} 
    {2050 2050s} 
    {2080 2080s}
  }

  puts "</table></td><td width=10></td><td><table>"
  
  onefield season "Season" {
    {custom "Custom"} 
    {djf "Dec/Jan/Feb"} 
    {mam "Mar/Apr/May"} 
    {jja "Jun/Jul/Aug"} 
    {son "Sep/Oct/Nov"}
    {ann "Annual"}
  }
  
  if {[info exists Form(season)]} {
    switch $Form(season) {
      djf { set Form(mstart) 12 ; set Form(mend)  2 }
      mam { set Form(mstart)  3 ; set Form(mend)  5 }
      jja { set Form(mstart)  6 ; set Form(mend)  8 }
      son { set Form(mstart)  9 ; set Form(mend) 11 }
      ann { set Form(mstart)  1 ; set Form(mend) 12 }
    }
  }
  
  set months [enumerate {January February March April May June July August September October Novermber December}]
  onefield mstart "From" $months
  onefield mend   "To" $months

  puts "          </table></td><td width=50></td></tr>"
  puts {        <tr><td colspan=4 align="center">}
  puts {          <input name="plot" type="SUBMIT" value="Plot graph">}
##  puts {          <input name="getdata" type="SUBMIT" value="Get data">}
  puts {        </td></tr>}
  puts "      </table>"
  puts "    </form>"
  puts "    <p>"

  if {[info exists Form(plot)]} {
    set combo [join [list $Form(gcmscen) $Form(var) $Form(decade)] "_"]
    if {[file exists cooked/${combo}.pgm]} {
      set choice [join [list $combo $Form(land) $Form(mstart) $Form(mend)] "_"]
      puts "    <p><a href=\"$ReqURI/data.txt?$choice\">ASCII data from this plot <b> (*)</b></a><p>"
      puts "    <img src=\"$ReqURI/plot.gif?$choice\">"
      puts "    <p/><b>(*)</b> The ASCII fields are derived from the image, and differ from the original data by consequent rounding errors"
    } else {
      set a [join [list $Form(gcmscen) * $Form(decade)] "_"]
      set b [glob -nocomplain cooked/$a.pgm]
      set avail {}
      foreach c $b {
        lappend avail [lindex [split $c _] 2]
      }
      puts "No data exists for the chosen combination.<br>These datasets are available: <p>"
      output_datasets_table $Form(gcmscen) $Form(var)
    }
  } else {
    puts "    <img src=\"$ReqURI/empty.gif\">"
  }

  puts "    </center>"
  puts "  </body>"
  puts "</html>"
}


###################### MAIN #####################

set tail [file tail $env(PATH_INFO)]

set ReqURI [lindex [split $env(REQUEST_URI) "?"] 0]

switch $tail {
  empty.gif {
    output_gif emptymap.gif
  }
  plot.gif {
    ##set rc [catch "exec ./gcmchgfld $env(QUERY_STRING)" a]
    ##puts "Content-type: text/plain\n"
    ##puts "*** $rc $a *** [lindex $a 0] ***"
    set a [exec ./gcmchgfld $env(QUERY_STRING)]
    if {[lindex $a 0]==0} {
      output_gif [lindex $a 1]
    } else {
      set tmp /tmp/[pid].gif
      catch "exec pbmtext \"Error: [lindex $a 1]\" | ppmtogif > $tmp" out
      output_gif $tmp
    }
  }
  data.txt {
    puts "Content-type: text/plain\n"
    puts [exec ./gcmchgfld -csv $env(QUERY_STRING)]
  }
  default {
    parse_form_input
    parse_query_string
    output_form
    ##puts "<p>[array get env]"
    ##puts "<p>[array get Form]"
  }
}
