#!/usr/bin/tclsh

proc hex2dec {hex} {
  set dec 0
  foreach digit [split $hex {}] {
    set i [string first $digit "0123456789ABCDEF"]
    if {$i<0} {set i 0}
    set dec [expr $dec*16+$i]
  }
  return $dec
}

proc unescape {text} {
  regsub -all {\+} $text " " text
  set out ""
  while {[set i [string first "%" $text]]>-1} {
    set a [string range $text 0 [expr $i-1]]
    set b [string range $text [expr $i+1] [expr $i+2]]
    set c [string range $text [expr $i+3] end]
    append out $a [format "%c" [hex2dec $b]]
    set text $c
  }
  append out $text    
  return $out
}

proc parse_form_input {} {
  global env Form
  set Form(querytitle) "none"
  if {[info exists env(CONTENT_LENGTH)]} {
    set text [read stdin]
    foreach item [split $text &] {
      set a [split $item =]
      set Form([lindex $a 0]) [unescape [lindex $a 1]]
    }
  }
}

######### MAIN #########

parse_form_input

puts "Content-type: text/html\n\n"
puts {<i><a href="/">IPCC-DDC Data Distribution Centre</a></i>}
puts "<h2>Feedback received</h2>"
puts "<blockquote>"
puts "<p>$Form(name)"
puts "<p>$Form(email)"
puts "<p>$Form(suggtype)"
regsub -all "\r\n" $Form(suggestion) "\n" sugg
regsub -all "\r" $sugg "\n" sugg
regsub -all "\n" $sugg "<br>" sugghtml
puts "<p>$sugghtml"
puts "</blockquote>"
puts "Thank you for your feedback."

set f [open "|sendmail badc@rl.ac.uk" w]
puts $f "From: ddc_feedback@ipcc-data.org"
puts $f "To: badc@rl.ac.uk"
puts $f "Subject: IPCC-DDC feedback (auto)::$Form(querytitle):"
puts $f ""
puts $f "$Form(name)"
puts $f "$Form(email)"
puts $f "$Form(suggtype)"
puts $f ""
puts $f "$sugg"
puts $f "."
close $f

puts "<p>It has been emailed to the website manager."
