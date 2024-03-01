#MIRACLE
load libMiracle.so
load libMiracleBasicMovement.so
load libmphy.so
load libmmac.so
load libUwmStd.so
#DESERT
load libuwcsmaaloha.so
load libuwip.so
load libuwstaticrouting.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so

#Create simulator
set ns [new Simulator]
$ns use-Miracle

#Set parameters
set opt(string1,string2) 5 
set opt(nn)         2.0 ;# Number of nodes
set opt(starttime)  1
set opt(stoptime)   100000
set opt(txduration) [expr $opt(stoptime) - $opt(starttime)]
set opt(freq)       25000.0
set opt(bw)         5000.0
set opt(ack_mode)   "setNoAckMode"
set opt(maxinterval) 10000

# set opt(tracefile)  "ogogo.tr"

# set opt(cltracefile)  "rororo.tr"

set opt(pktsize)    150
set opt(cbr_period) 1000
set opt(bitrate)    300
set opt(txpower)    1000

#Set bash parameters
set opt(bash_parameters) 0; #1 for active bash params
if {$opt(bash_parameters)} {
    if {$argc != 2} {
        puts "The script requires two inputs"
    } else {
        set opt(pktsize)    [lindex $argv 0]
        set opt(cbr_period) [lindex $argv 1]
    }
}

#Set random generator
set opt(rngstream) 1; # better to pass it via bash

global defaultRNG

for {set k 0} {$k > $opt(rngstream)} {incr k} {
    $defaultRNG next-substream
}

#Set common objects
set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq $opt(freq)
$data_mask setBandwidth $opt(bw)

#Common modules config - bind
Module/UW/CBR set packetSize_       $opt(pktsize)
Module/UW/CBR set period_           $opt(cbr_period)
Module/UW/CBR set PoissonTraffic_   1
Module/MPhy/BPSK set BitRate_         $opt(bitrate)
Module/MPhy/BPSK set TxPower_         $opt(txpower)

#Create a node function
proc createNode { id } {
    global ns propagation
    set opt(tracefile)  "ogogo.tr"
    set opt(cltracefile)  "rororo.tr"
    #Create modules
    set node($id)   [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]
    set cbr($id)    [new Module/UW/CBR]
    set udp($id)    [new Module/UW/UDP]
    set ipr($id)    [new Module/UW/StaticRouting]
    set ipif($id)   [new Module/UW/IP]
    set mll($id)    [new Module/UW/MLL]
    set mac($id)    [new Module/UW/CSMA_ALOHA]
    set phy($id)    [new Module/MPhy/BPSK]
    #Add modules to nodes
    #$node addModule <layer> <module> <cl_trace> <tag>
    $node($id) addModule 7 $cbr($id) 0 "CBR"
    $node($id) addModule 6 $udp($id) 0 "UDP"
    $node($id) addModule 5 $ipr($id) 0 "IPR"
    $node($id) addModule 4 $ipif($id) 0 "IPF"
    $node($id) addModule 3 $mll($id) 0 "MLL"
    $node($id) addModule 2 $mac($id) 0 "MAC"
    $node($id) addModule 1 $phy($id) 0 "PHY"
    #Connect layers
    #$node setConnection <upper> <lower> <trace>
    $node($id) setConnection $cbr($id) $udp($id) 0
    $node($id) setConnection $udp($id) $ipr($id) 0
    $node($id) setConnection $ipr($id) $ipif($id) 0
    $node($id) setConnection $ipif($id) $mll($id) 0
    $node($id) setConnection $mll($id) $mac($id) 0
    $node($id) setConnection $mac($id) $phy($id) 0
    $node($id) addToChannel $channel $phy($id) 0
    #position, interference and other parameters
    set tmp_ [expr ($id) + 1]
    $ipif($id) addr $tmp_
    set position($id) [new "Position/BM"]
    $node($id) addPosition $position($id)
    set interf_data($id) [new "MInterference/MIV"]
    $interf_data($id) set maxinterval_ $opt(maxinterval)
    $phy($id) setPropagation $propagation
    $phy($id) setSpectralMask $data_mask
    $phy($id) setInterference $interf_data($id)
}

#Create the sink: one app and one port number per node
for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
    set cbr_sink($cnt) [new Module/UW/CBR]
    
    # set ipr_sink($cnt) [new Module/UW/StaticRouting]
    # set ipif_sink($cnt) [new Module/UW/IP]
    # set mll_sink($cnt) [new Module/UW/MLL]
    # set mac_sink($cnt) [new Module/UW/CSMA_ALOHA]
    # set ipif_sink($cnt) [new Module/UW/IP]
}
set udp_sink [new Module/UW/UDP]
# for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
#     $node_sink addModule 7 $cbr_sink($cnt) 0 "CBR"
# }
# for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
#     $node_sink setConnection $cbr_sink($cnt) $udp_sink 0
# }
for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
    set portnum_sink($cnt) [$udp_sink assignPort $cbr_sink($cnt)]
}

#Create nodes and connect them
for {set id 0} {$id < $opt(nn)} {incr id} {
    createNode $id
}
proc connectNodes {id1} {
    global ipif ipr portnum cbr cbr_sink ipif_sink portnum_sink ipr_sink
    $cbr($id1) set destAddr_ [$ipif_sink addr]
    $cbr($id1) set destPort_ $portnum_sink($id1)
    $cbr_sink($id1) set destAddr_ [$ipif($id1) addr]
    $cbr_sink($id1) set destPort_ $portnum($id1)
}
for {set id1 0} {$id < $opt(nn)} {incr id1} {
    connectNodes $id1
}

#Fill ARP table
for {set id1 0} {$id1 < $opt(nn)} {incr id1} {
    for { set id2 0} {$id2 < $opt(nn)} {incr id2} {
        $mll($id1) addentry [$ipif($id2) addr] [$mac($id2) addr]
    }
    $mll($id1) addentry [$ipif_sink addr] [$mac_sink addr]
    $mll_sink addentry [$ipif($id1) addr] [$mac($id1) addr]
}

#Set position
$position(0) setX_ 0
$position(0) setY_ 0
$position(0) setZ_ -1000
$position(1) setX_ 200
$position(1) setY_ 200
$position(1) setZ_ -1000
# $position(2) setX_ 500
# $position(2) setY_ 500
# $position(2) setZ_ -1000
# $position(3) setX_ 2000
# $position(3) setY_ 2000
# $position(3) setZ_ -1000
# $position(4) setX_ 0
# $position(4) setY_ 0
# $position(4) setZ_ -1000

#Routing table
$ipr(0) addRoute [$ipif_sink addr] [$ipif(1) addr]
$ipr(1) addRoute [$ipif_sink addr] [$ipif_sink addr]

for {set id1 0} {$id1 < $opt(nn)} {incr id1} {
    $ns at $opt(starttime) "$cbr($id1) start"
    $ns at $opt(stoptime)  "$cbr($id1) start"
}

proc finish {} {

}
$ns at [expr $opt(stoptime) + 250.0] "finsih; $ns halt"
$ns run