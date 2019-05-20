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
puts "<h2>Registration received</h2>"
puts "<blockquote>"
puts "<p>$Form(name)"
puts "<p>$Form(email)"
regsub -all "\r\n" $Form(describe) "\n" desc
regsub -all "\r" $desc "\n" desc
regsub -all "\n" $desc "<br>" deschtml
puts "<p>$deschtml"
puts "</blockquote>"
puts "Thank you for your registration."

set f [open "|sendmail m.n.juckes@rl.ac.uk" w]
puts $f "From: $Form(name) <$Form(email)>"
puts $f "To: m.n.juckes@rl.ac.uk"
puts " "
puts $f "Subject: \[IPCC DDC registration\] $Form(name)"
puts $f ""
puts $f "Name: $Form(name)"
puts $f "Email: $Form(email)"
puts $f ""
puts $f "$desc"
puts $f "."
close $f

puts "<p>It has been emailed to the website manager."
