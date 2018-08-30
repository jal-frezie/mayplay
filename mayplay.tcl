#!/usr/bin/wish

# Copyright 2018 Jasper Taylor
# 
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

package require http

set powerCmd {echo PPOWER}
set sleepCmd {echo SLEEP}

# this bit straight from Simile
# tile creates: TkCaptionFont TkTooltipFont TkFixedFont TkHeadingFont 
#               TkMenuFont TkIconFont TkTextFont TkDefaultFont
# ...on Linux. On the Mac it makes:
# TkCaptionFont TkClassicDefaultFont TkTooltipFont TkHeadingFont TkTextFont 
# TkDefaultFont
# ...so...
if {[string equal aqua [tk windowingsystem]]} {
    set menuFont TkDefaultFont
    set niceSize 12
} else {
    set menuFont TkMenuFont
    set niceSize 9
}
set niceSize [expr {round($niceSize*[tk scaling])}]

font configure TkDefaultFont -size $niceSize
font configure TkTextFont -size $niceSize
font configure TkMenuFont -size $niceSize

set base [open ~/.mayplay r]
set hasGenres 1
foreach pair [lrange [split [read $base] \n] 0 end-1] {
    if {[llength $pair]==2} {set hasGenres 0}
    if {!$hasGenres} {
	set pair [linsert $pair 2 {}]
    }
    lappend pairz [lrange $pair 0 2]
    foreach butNo [lrange $pair 3 end] {
	set presets($butNo) [lindex $pair 0]
    }
}
close $base

set fil 0
set vol 30

bind . <Return> PlayMatch
for {set q 0} {$q<10} {incr q} {
    bind . <Control-Key-$q> {set downTime [clock clicks -milliseconds]; 
	PlayPre %K}
}
bind . <Up> {Preload -1}
bind . <Down> {Preload 1}
bind . <Control-Up> RaiseVolume
bind . <Control-Down> LowerVolume
bind . <Control-space> {.butz.b invoke}

proc AddToMenus {lyne} {
    global gmnu

    $gmnu.genreAll add command -label [lindex $lyne 0] \
	-command [list PlayFile [lindex $lyne 1]]
    set genres [lindex $lyne 2]
    if {[string first , $genres] >=0} {
	set genreList [split $genres ,]
    } elseif {[string first / $genres] >=0} {
	set genreList [split $genres /]
    } elseif {$genres eq "No genre"} {
	set genreList [list $genres]
    } else {
	set genreList [split $genres " "]
	while {[set conj [lsearch $genreList and]]>0} {
	    # we have both kinds of music here...
	    set western [incr conj]
	    set country [incr conj -2]
	    set genreList [lreplace $genreList $country $western \
				[lrange $genreList $country $western]]
	}
    }
# removed iplayer interface cos we have 128kbps streams!
#    if {[string first BBC [lindex $lyne 0]]==0} {
#	set genreList Iplayer
#    }
    foreach genreItem $genreList {
	set genre [string totitle [string trim $genreItem]]
	if {[lsearch {{} Radio Live} $genre] >= 0} continue
	set genreMenu $gmnu.genre$genre
	if {![winfo exists $genreMenu]} {
	    menu $genreMenu -tearoff 0
	}
	$genreMenu add command -label [lindex $lyne 0] \
	    -command [list PlayFile [lindex $lyne 1]]
	if {[$genreMenu index end]==2} { ;# worth including as a category
	    $gmnu add cascade -label $genre -menu $genreMenu
	}
    }
}

proc PlayMatch {} {
    global pairz entree

    set sought [string tolower [.e get]]
    if {[info exists ::stm]} {
	if {![string length $sought]} {
#	    .e insert 0 [lindex [lindex $pairz $entree] 0]
	    StopFile
	    return
	}
    } else {
	if {![string length $sought]} {
	    set sought [lindex [lindex $pairz $entree] 0]
	}
    }

    set soonest 1000
    set foundAt 0
    set lsought [string tolower $sought]
    foreach lyne $pairz {
	set find [string first $lsought [string tolower [lindex $lyne 0]]]
	if {$find>-1 && $find<$soonest} {
	    set soonest $find
	    puts "found $sought at $soonest in [lindex $lyne 0] at $foundAt"
	    set bestest $foundAt
	}
	incr foundAt
    }
    if {$soonest<1000} {
	.e delete 0 end
	set entree $bestest
	PlayFile [lindex [lindex $pairz $entree] 1]
    } else {
	PlayPastedFile 
    }
}

proc Stop {is} {
    global go

    if {$is} {
	set go no
	.butz.b config -text Resume
    } else {
	set go yes
	.butz.b config -text Pause
    }
}

proc Preload {off} {
    global pairz entree

    .e delete 0 end
    incr entree $off
    .e insert 0 [lindex [lindex $pairz $entree] 0]
}
	       
proc PlayPre {bun} {
    global presets

    set holdTime [expr {[clock clicks -milliseconds]-$::downTime}]
    #puts "button $bun down for $holdTime ms"
    if {$holdTime<1000} {
	if {[info exists presets($bun)]} {
	    .e delete 0 end
	    .e insert 0 $presets($bun)
	    PlayMatch
	}
    } else {
	if {[info exists ::stm]} { ;# playing something
	    set presets($bun) [lindex [lindex $::pairz $::entree] 0]
	    .e delete 0 end
	    .e insert 0 $presets($bun)
	}
    }
}

pack [frame .b  -relief sunken -bg gray -bd 2] -side left -fill y
pack [frame .b.f -width 20 -relief raised -bg blue3 -bd 2] -side bottom
bind .b <Configure> {.b.f config -height \
			 [expr {([winfo height .b]-4)*$fil/100}]}
#pack [frame .v  -relief sunken -bg gray -bd 2] -side right -fill y
#pack [frame .v.f -width 20 -relief raised -bg red3 -bd 2] -side bottom
#bind .v <Configure> {.v.f config -height [expr [winfo height .b]*$vol/102]}

pack [frame .t]
pack [::ttk::combobox .t.cb -textvariable target \
	  -width 10 -values [concat localhost barbie raspberrypi spacehopper] \
	  -state readonly] -side left
set target localhost
set gmnu .t.mb.m
pack [menubutton .t.mb -text Play... -relief raised -menu $gmnu] -side right
menu $gmnu -tearoff 0
$gmnu add cascade -menu [menu $gmnu.genreAll -tearoff 0] -label All
foreach lyne $pairz {
    AddToMenus $lyne
}

pack [entry .e]

frame .butz
pack [button .butz.q -text Vol- -command LowerVolume] -side left
pack [button .butz.b -text Resume -command PlayPastedFile -state disabled] \
    -side left
pack [button .butz.l -text Vol+ -command RaiseVolume] -side right
pack [button .butz.b2 -text Play -command PlayMatch] -side right
pack .butz
pack [scale .vol -orient h -from 0 -to 100 -command SetVolume -variable vol] \
    -fill x -expand 1
foreach pLine {0 1} {
    pack [frame [set pFrame .pFrame$pLine]] -fill x -expand true
    foreach pBut {0 1 2 3 4} {
	set nBut [expr {5*$pLine+$pBut}]
	set bId $pFrame.preset$nBut
	pack [button $bId -command "PlayPre $nBut" -text $nBut] \
	    -side left -fill x -expand true
	bind $bId <ButtonPress-1> {set downTime [clock clicks -milliseconds]}
    }
}
pack [label .l -text "No station"]
pack [message .l1 -width [expr {32*$niceSize}] -bg white -text "No genre"]
pack [message .l2 -width [expr {32*$niceSize}] -bg white -text "No song"]
pack [label .l3 -text "Stopped"]
Stop yes

if {[string length $argv]} {
    .e delete 0 end
    .e insert $argv
    PlayFile $argv
}

proc PlayPastedFile {} {
    PlayFile [.e get]
    .e delete 0 end
}

proc PlayFile {url} {
    global stm

    if {[info exists stm]} {
	StopFile
    }
    eval exec $::powerCmd
#    if {[string first BBC $url]==0} {
#	set fifo [file normalize ~/.mayplay.fifo]
#	set action "ssh $::target mplayer -slave -novideo $fifo"
#    } else {
    set action [list mplayer -volume $::vol -slave $url]
    set quer [string first ? $url]
    if {$quer >= 0} {
	set handler [string range $url 0 $quer-1]
    } else {
	set handler $url
    }
    if {[lsearch {.pls .m3u .asx} [file extension $handler]]>=0} {
	set action [linsert $action end-1 -playlist]
    }
    if {$::target ne "localhost"} {
	set action [concat [list ssh $::target] $action]
    }
#    }
    puts "Doing $action"
    .l3 configure -text "Kicking off..."
    set stm [open "|$action 2>@1" {RDWR NONBLOCK}]
    fconfigure $stm -blocking 0
    fileevent $stm readable [list GobbleStatus $url]
    .butz.b configure -text Pause -command Pause -state normal
    .butz.b2 configure -text Stop
#    if {[string first BBC $url]==0} {
#	set action "get_iplayer --stream --type=liveradio \"$url\" > $fifo"
#	puts "...and $action"
#	open |$action {WRONLY NONBLOCK}
#	TweakData $url $url $url
#    }
}

# alternative way of setting volume if using pulseaudio -- not in use
proc GetPulseId {stm} {
    global pulseId
    set pacDump [exec pacmd list-sink-inputs]
    set myPsIdLocn [string first "application.process.id = \"[pid $stm]\"" \
			$pacDump]
    set myIdxLocn [string last "index:" $pacDump $myPsIdLocn]
    scan [string range $pacDump $myIdxLocn+7 $myPsIdLocn] %d pulseId
}

proc Pause {} {
    global stm
#    puts -nonewline $stm " "
    puts $stm pause
    flush $stm
}

proc LowerVolume {} {
    SetVolume [incr ::vol -1]
}

proc SetVolume {percent} {
    global stm pulseId
    if {![info exists stm]} return
#    exec pacmd set-sink-input-volume $pulseId [expr {$percent*800}]
    puts $stm "vol $percent 1"
    flush $stm
}

proc RaiseVolume {} {
    SetVolume [incr ::vol]
}

proc GobbleStatus {url} {
    global stm vol fil name genre

    if {![info exists stm]} {
	puts Derrr!
	return
    }
    set line [gets $stm]
    if {[eof $stm]} {
	puts $line
	StopFile
	return
    }
# some stations only work if the next line is included, though it does nothing
    set bin $line
    while {[string length $line]} {
	switch -glob -- $line {
	    "Name   : *" {
		set name [string range $line 9 end]
		set genre "No genre" ;# hope it comes after name
		regsub {^[^A-Za-z]*} $name {} name ;# remove leading non-alpha
		if {[string length $name]>48} {
		    set name [string replace $name 40 end-6 ...]
		}
	    } "Genre  : *" {
		set genre [string range $line 9 end]
		.l1 config -text $genre
	    } "ICY Info: *" {
		set titleStart \
		    [expr {[string first StreamTitle=' $line]+13}]
		set titleEnd [expr {[string first \; $line $titleStart]-2}]
#puts "Songline is $line start $titleStart end $titleEnd"
		.l2 config -text [string range $line $titleStart $titleEnd]
	    } "A:*" {
		set n [scan $line "A:%f (%s of %f (unknown) %f%% %d%%" \
			   a b c d fil]
		if {$n<2} {
		    puts $line
		    return
		}
		if {!$::go} {
		    Stop no
		    if {[info exists name]} {
			TweakData $name $url $genre
		    }
#		    GetPulseId $stm
		    SetVolume $vol
		}
		event generate .b <Configure>
		.l3 config -text "Vol: $vol ($b"
		if {$n==5} {
		    if {!$fil && \
			    [string equal Pause [.butz.b cget -command]]} {
# restart
#			StopFile
#			PlayFile $url
		    }
		}
	    } "*Volume: *" {
		if {[scan $line "%s %d %%" VTX vol]==2} {
#		    event generate .v <Configure>
		}
	    } "Cache fill: *" {
		set n [scan $line "Cache fill: %f%% (%d bytes)" \
			   fil a]
		if {$n==2} {
		    event generate .b <Configure>
		} else {
		    puts $line
		}
	    } "*=====  PAUSE  =====*" {
		Stop yes
	    } "Exiting... (End of file)" {
		StopFile
		return
	    } "No bind found for key *" {
		# spurious: do nothing
	    } default {
		puts $line
	    }
	}
	set line [gets $stm]
    }
}

proc TweakData {name url genre} {
    global pairz entree

    .l config -text $name
    set entry [list $name $url $genre]
    set entree [lsearch -exact $pairz $entry]
    if {$entree==-1} {
	puts "no $entry in $pairz"
	AddToMenus $entry
	set count [llength $pairz]
	while {$count>0} {
	    incr count -1
	    set line [lindex $pairz $count]
	    if {[string equal $name [lindex $line 0]] || \
		    [string equal $url [lindex $line 1]]} {
		set pairz [lreplace $pairz $count $count]
	    }
	}			    
	lappend pairz $entry
	set pairz  [lsort -dictionary -index 0 $pairz]
	set entree [lsearch -exact $pairz $entry]
    }
}

proc StopFile {} {
    global stm
puts "screech of brakes"

    eval exec $::sleepCmd
    if {[info exists stm]} {
	fileevent $stm readable {}
	puts $stm "q"
	catch {
	    flush $stm
	}
	close $stm
	unset stm
    }
    .l config -text "No station"
    .l1 config -text "No genre"
    .l2 config -text "No song"
    .l3 config -text "Stopped"
    .butz.b configure -state disabled
    .butz.b2 configure -text Play
    Stop yes
}

wm protocol . WM_DELETE_WINDOW {MenuContentsIntoFile}
image create photo monster -file ~/Music/multimedia.png
wm iconphoto . monster

proc MenuContentsIntoFile {} {
    global pairz presets

    StopFile
    set base [open ~/.mayplay.new w]
    foreach line $pairz {
	puts -nonewline $base $line
	for {set pre 0} {$pre < 10} {incr pre} {
	    if {[info exists presets($pre)] && \
		    [string equal $presets($pre) [lindex $line 0]]} {
		puts -nonewline $base " $pre"
	    }
	}
	puts $base {}
    }
    close $base
    file rename -force ~/.mayplay.new ~/.mayplay
    exit
}
