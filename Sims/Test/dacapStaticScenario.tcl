######################################
# Flags to enable or disable options #
######################################
set opt(verbose) 			1
set opt(trace_files)		0
set opt(bash_parameters) 	1

#####################
# Library Loading   #
#####################


load libMiracle.so
load libMiracleBasicMovement.so
load libmphy.so
load libmmac.so
load libUwmStd.so
load libuwip.so
load libuwstaticrouting.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so
load libuwdacap.so
load libuwinterference.so
load libuwphy_clmsgs.so
load libuwstats_utilities.so
load libuwphysical.so
load libuwcsmaaloha.so

#############################
# NS-Miracle initialization #
#############################
# You always need the following two lines to use the NS-Miracle simulator
set ns [new Simulator]
$ns use-Miracle

##################
# Tcl variables  #
##################
set opt(nn)                 4.0 ;# Number of Nodes
set opt(pktsize)            125  ;# Pkt sike in byte
set opt(starttime)          1	
set opt(stoptime)           100000 
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)] ;# Duration of the simulation
set opt(txpower)            180.0  ;#Power transmitted in dB re uPa
set opt(maxinterval_)       20.0 ;#Need to figure out what this does
set opt(freq)               25000.0 ;#Frequency used in Hz
set opt(bw)                 5000.0	;#Bandwidth used in Hz
set opt(bitrate)            4800.0	;#bitrate in bps
set opt(ack_mode)           "setNoAckMode"
set opt(cbr_period)     100
set opt(pktsize)	125
set opt(rngstream)	1
set opt(scenario) 0

#######################
# set BASH-parameters #
#######################
if {$opt(bash_parameters)} {
	if {$argc != 3} {
		puts "The script requires three inputs:"
		puts "- the first for the seed"
		puts "- the second one is for the Poisson CBR period"
		puts "- the third one is the cbr packet size (byte)"
        #puts "- the fifth one is the number of nodes"
        #puts "- the sixth one is the scenario"
        puts "./ns <filepath> <seed> <poisson cbr period> <pktSize> <bw>"
		return
	} else {
		set opt(rngstream)      [lindex $argv 0]
		set opt(cbr_period)     [lindex $argv 1]
		set opt(pktsize)        [lindex $argv 2]
        #set opt(bw)             [lindex $argv 3]
        #set opt(nn)             [lindex $argv 4]
        #set opt(scenario)       [lindex $argv 5]
	}
}

if {$opt(trace_files)} {
	set opt(tracefilename) "./test_uwdacap.tr"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "./test_uwdacap.cltr"
	set opt(cltracefile) [open $opt(tracefilename) w]
} else {
	set opt(tracefilename) "/dev/null"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "/dev/null"
	set opt(cltracefile) [open $opt(cltracefilename) w]
}

set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       $opt(freq)
$data_mask setBandwidth  $opt(bw)

#########################
# Module Configuration  #
#########################
Module/UW/CBR set packetSize_          $opt(pktsize)
Module/UW/CBR set period_              $opt(cbr_period)
Module/UW/CBR set PoissonTraffic_      1
Module/UW/CBR set debug_               0

Module/UW/DACAP set debug_               0

Module/UW/PHYSICAL  set MaxTxSPL_dB_               $opt(txpower)

#Module/MPhy/BPSK  set TxPower_               $opt(txpower)

proc createNode { id } {
    #Makes variables accessable
    global channel propagation data_mask ns cbr position node udp portnum ipr ipif channel_estimator
    global phy posdb opt rvposx rvposy rvposz mhrouting mll mac woss_utilities woss_creator db_manager
    global node_coordinates

    #Creates a node in the node array
    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

    set position($id) [new "Position/BM"]
    $node($id) addPosition $position($id)

    if {$opt(scenario) == 0} {
        if {$id == 0} {
            for {set cnt 0} {$cnt < 4} {incr cnt} {
		        set cbr($id,$cnt)  [new Module/UW/CBR]
	        }
            set udp($id)  [new Module/UW/UDP]
            set ipr($id)  [new Module/UW/StaticRouting]
            set ipif($id) [new Module/UW/IP]
            set mll($id)  [new Module/UW/MLL] 
            set mac($id)  [new Module/UW/DACAP]
            #set mac($id)  [new Module/UW/CSMA_ALOHA]   
            set phy($id)  [new Module/UW/PHYSICAL]

            for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
                $node($id) addModule 7 $cbr($id,$cnt)   1  "CBR"
            }
            $node($id) addModule 6 $udp($id)   1  "UDP"
            $node($id) addModule 5 $ipr($id)   1  "IPR"
            $node($id) addModule 4 $ipif($id)  1  "IPF"   
            $node($id) addModule 3 $mll($id)   1  "MLL"
            $node($id) addModule 2 $mac($id)   1  "MAC"
            $node($id) addModule 1 $phy($id)   1  "PHY"

            for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
                $node($id) setConnection $cbr($id,$cnt)   $udp($id)   0
                set portnum($id,$cnt) [$udp($id) assignPort $cbr($id,$cnt) ]
            }
            $node($id) setConnection $udp($id)   $ipr($id)   1
            $node($id) setConnection $ipr($id)   $ipif($id)  1
            $node($id) setConnection $ipif($id)  $mll($id)   1
            $node($id) setConnection $mll($id)   $mac($id)   1
            $node($id) setConnection $mac($id)   $phy($id)   1
            $node($id) addToChannel  $channel    $phy($id)   1

            $ipif($id) addr [expr $id + 1]
    
            set position($id) [new "Position/BM"]
            $node($id) addPosition $position($id)
            set posdb($id) [new "PlugIn/PositionDB"]
            $node($id) addPlugin $posdb($id) 20 "PDB"
            $posdb($id) addpos [$ipif($id) addr] $position($id)

            $position($id) setX_ 0
            $position($id) setY_ 0
            $position($id) setZ_ -100

            set interf_data($id) [new "Module/UW/INTERFERENCE"]
            $interf_data($id) set maxinterval_ $opt(maxinterval_)
            $interf_data($id) set debug_       0

            $phy($id) setPropagation $propagation
            
            $phy($id) setSpectralMask $data_mask
            $phy($id) setInterference $interf_data($id)
            $mac($id) $opt(ack_mode)
        }
        if {$id == 1} {
            set cbr($id,0)  [new Module/UW/CBR]
            set cbr($id,$id)  [new Module/UW/CBR]
            set udp($id)  [new Module/UW/UDP]
            set ipr($id)  [new Module/UW/StaticRouting]
            set ipif($id) [new Module/UW/IP]
            set mll($id)  [new Module/UW/MLL] 
            set mac($id)  [new Module/UW/DACAP]
            #set mac($id)  [new Module/UW/CSMA_ALOHA]   
            set phy($id)  [new Module/UW/PHYSICAL]

            $node($id) addModule 7 $cbr($id,0)   1  "CBR"
            $node($id) addModule 7 $cbr($id,$id)   1  "CBR"
            $node($id) addModule 6 $udp($id)   1  "UDP"
            $node($id) addModule 5 $ipr($id)   1  "IPR"
            $node($id) addModule 4 $ipif($id)  1  "IPF"   
            $node($id) addModule 3 $mll($id)   1  "MLL"
            $node($id) addModule 2 $mac($id)   1  "MAC"
            $node($id) addModule 1 $phy($id)   1  "PHY"

            
		    $node($id) setConnection $cbr($id,0)   $udp($id)   0
		    set portnum($id,0) [$udp($id) assignPort $cbr($id,0) ]
            $node($id) setConnection $cbr($id,$id)   $udp($id)   0
		    set portnum($id,$id) [$udp($id) assignPort $cbr($id,$id) ]
            $node($id) setConnection $udp($id)   $ipr($id)   1
            $node($id) setConnection $ipr($id)   $ipif($id)  1
            $node($id) setConnection $ipif($id)  $mll($id)   1
            $node($id) setConnection $mll($id)   $mac($id)   1
            $node($id) setConnection $mac($id)   $phy($id)   1
            $node($id) addToChannel  $channel    $phy($id)   1

            $ipif($id) addr [expr $id + 1]
    
            set position($id) [new "Position/BM"]
            $node($id) addPosition $position($id)
            set posdb($id) [new "PlugIn/PositionDB"]
            $node($id) addPlugin $posdb($id) 20 "PDB"
            $posdb($id) addpos [$ipif($id) addr] $position($id)

            $position($id) setX_ -250
            $position($id) setY_ 433
            $position($id) setZ_ -100

            set interf_data($id) [new "Module/UW/INTERFERENCE"]
            $interf_data($id) set maxinterval_ $opt(maxinterval_)
            $interf_data($id) set debug_       0

            $phy($id) setPropagation $propagation
            
            $phy($id) setSpectralMask $data_mask
            $phy($id) setInterference $interf_data($id)
            $mac($id) $opt(ack_mode)
        }
        if {$id == 2} {
            set cbr($id,0)  [new Module/UW/CBR]
            set cbr($id,$id)  [new Module/UW/CBR]
            set udp($id)  [new Module/UW/UDP]
            set ipr($id)  [new Module/UW/StaticRouting]
            set ipif($id) [new Module/UW/IP]
            set mll($id)  [new Module/UW/MLL] 
            set mac($id)  [new Module/UW/DACAP]
            #set mac($id)  [new Module/UW/CSMA_ALOHA]   
            set phy($id)  [new Module/UW/PHYSICAL]

            $node($id) addModule 7 $cbr($id,0)   1  "CBR"
            $node($id) addModule 7 $cbr($id,$id)   1  "CBR"
            $node($id) addModule 6 $udp($id)   1  "UDP"
            $node($id) addModule 5 $ipr($id)   1  "IPR"
            $node($id) addModule 4 $ipif($id)  1  "IPF"   
            $node($id) addModule 3 $mll($id)   1  "MLL"
            $node($id) addModule 2 $mac($id)   1  "MAC"
            $node($id) addModule 1 $phy($id)   1  "PHY"

            
		    $node($id) setConnection $cbr($id,0)   $udp($id)   0
		    set portnum($id,0) [$udp($id) assignPort $cbr($id,0) ]
            $node($id) setConnection $cbr($id,$id)   $udp($id)   0
		    set portnum($id,$id) [$udp($id) assignPort $cbr($id,$id) ]
            $node($id) setConnection $udp($id)   $ipr($id)   1
            $node($id) setConnection $ipr($id)   $ipif($id)  1
            $node($id) setConnection $ipif($id)  $mll($id)   1
            $node($id) setConnection $mll($id)   $mac($id)   1
            $node($id) setConnection $mac($id)   $phy($id)   1
            $node($id) addToChannel  $channel    $phy($id)   1

            $ipif($id) addr [expr $id + 1]
    
            set position($id) [new "Position/BM"]
            $node($id) addPosition $position($id)
            set posdb($id) [new "PlugIn/PositionDB"]
            $node($id) addPlugin $posdb($id) 20 "PDB"
            $posdb($id) addpos [$ipif($id) addr] $position($id)

            $position($id) setX_ 700
            $position($id) setY_ 0
            $position($id) setZ_ -100

            set interf_data($id) [new "Module/UW/INTERFERENCE"]
            $interf_data($id) set maxinterval_ $opt(maxinterval_)
            $interf_data($id) set debug_       0

            $phy($id) setPropagation $propagation
            
            $phy($id) setSpectralMask $data_mask
            $phy($id) setInterference $interf_data($id)
            $mac($id) $opt(ack_mode)
        }
        if {$id == 3} {
            set cbr($id,0)  [new Module/UW/CBR]
            set cbr($id,$id)  [new Module/UW/CBR]
            set udp($id)  [new Module/UW/UDP]
            set ipr($id)  [new Module/UW/StaticRouting]
            set ipif($id) [new Module/UW/IP]
            set mll($id)  [new Module/UW/MLL]
            #set mac($id)  [new Module/UW/CSMA_ALOHA] 
            set mac($id)  [new Module/UW/DACAP]  
            set phy($id)  [new Module/UW/PHYSICAL]

            $node($id) addModule 7 $cbr($id,0)   1  "CBR"
            $node($id) addModule 7 $cbr($id,$id)   1  "CBR"
            $node($id) addModule 6 $udp($id)   1  "UDP"
            $node($id) addModule 5 $ipr($id)   1  "IPR"
            $node($id) addModule 4 $ipif($id)  1  "IPF"   
            $node($id) addModule 3 $mll($id)   1  "MLL"
            $node($id) addModule 2 $mac($id)   1  "MAC"
            $node($id) addModule 1 $phy($id)   1  "PHY"

            
		    $node($id) setConnection $cbr($id,0)   $udp($id)   0
		    set portnum($id,0) [$udp($id) assignPort $cbr($id,0) ]
            $node($id) setConnection $cbr($id,$id)   $udp($id)   0
		    set portnum($id,$id) [$udp($id) assignPort $cbr($id,$id) ]
            $node($id) setConnection $udp($id)   $ipr($id)   1
            $node($id) setConnection $ipr($id)   $ipif($id)  1
            $node($id) setConnection $ipif($id)  $mll($id)   1
            $node($id) setConnection $mll($id)   $mac($id)   1
            $node($id) setConnection $mac($id)   $phy($id)   1
            $node($id) addToChannel  $channel    $phy($id)   1

            $ipif($id) addr [expr $id + 1]
    
            set position($id) [new "Position/BM"]
            $node($id) addPosition $position($id)
            set posdb($id) [new "PlugIn/PositionDB"]
            $node($id) addPlugin $posdb($id) 20 "PDB"
            $posdb($id) addpos [$ipif($id) addr] $position($id)

            $position($id) setX_ -300
            $position($id) setY_ -520
            $position($id) setZ_ -100

            set interf_data($id) [new "Module/UW/INTERFERENCE"]
            $interf_data($id) set maxinterval_ $opt(maxinterval_)
            $interf_data($id) set debug_       0

            $phy($id) setPropagation $propagation
        
            $phy($id) setSpectralMask $data_mask
            $phy($id) setInterference $interf_data($id)
            $mac($id) $opt(ack_mode)
            
        }

        
    }                                                                                                                                                                                                           
}


if {$opt(scenario) == 0} {
    for {set id 0} {$id < 4} {incr id} {
        createNode $id
    }
    #Setup Flows / Inter-node module connection
    $cbr(0,0) set destAddr_ [$ipif(0) addr]
    $cbr(0,1) set destAddr_ [$ipif(1) addr]
    $cbr(0,2) set destAddr_ [$ipif(2) addr]
    $cbr(0,3) set destAddr_ [$ipif(3) addr]
    $cbr(1,0) set destAddr_ [$ipif(0) addr]
    $cbr(1,1) set destAddr_ [$ipif(1) addr]
    $cbr(2,0) set destAddr_ [$ipif(0) addr]
    $cbr(2,2) set destAddr_ [$ipif(2) addr]
    $cbr(3,0) set destAddr_ [$ipif(0) addr]
    $cbr(3,3) set destAddr_ [$ipif(3) addr]

    $cbr(0,0) set destPort_ $portnum(0,0)
    $cbr(0,1) set destPort_ $portnum(1,0)       
    $cbr(0,2) set destPort_ $portnum(2,0)    
    $cbr(0,3) set destPort_ $portnum(3,0)    
    $cbr(1,0) set destPort_ $portnum(0,1)
    $cbr(1,1) set destPort_ $portnum(1,1)
    $cbr(2,0) set destPort_ $portnum(0,2)
    $cbr(2,2) set destPort_ $portnum(2,2)
    $cbr(3,0) set destPort_ $portnum(0,3)
    $cbr(3,3) set destPort_ $portnum(3,3)
    
            

    #Fill ARP tables
    $mll(0) addentry [$ipif(1) addr] [$mac(1) addr]
    $mll(0) addentry [$ipif(2) addr] [$mac(2) addr]
    $mll(0) addentry [$ipif(3) addr] [$mac(3) addr]
    $mll(1) addentry [$ipif(0) addr] [$mac(0) addr]
    $mll(2) addentry [$ipif(0) addr] [$mac(0) addr]
    $mll(3) addentry [$ipif(0) addr] [$mac(0) addr]

    #Routing tables
    for {set id1 0} {$id1 < 4} {incr id1} {
        for {set id2 0} {$id2 < 4} {incr id2} {
            if {$id1 == 0} {
                $ipr($id1) addRoute [$ipif($id2) addr] [$ipif($id2) addr]
            } else {
                if {$id1 == $id2} {
                    $ipr($id1) addRoute [$ipif($id2) addr] [$ipif($id2) addr]
                } else {
                    $ipr($id1) addRoute [$ipif($id2) addr] [$ipif(0) addr]
                }
            }
        }
    }
    #Start/Stop Timers
    $ns at $opt(starttime)    "$cbr(0,1) start"
    $ns at $opt(stoptime)     "$cbr(0,1) stop"
    $ns at $opt(starttime)    "$cbr(0,2) start"
    $ns at $opt(stoptime)     "$cbr(0,2) stop"
    $ns at $opt(starttime)    "$cbr(0,3) start"
    $ns at $opt(stoptime)     "$cbr(0,3) stop"
    $ns at $opt(starttime)    "$cbr(1,0) start"
    $ns at $opt(stoptime)     "$cbr(1,0) stop"
    $ns at $opt(starttime)    "$cbr(2,0) start"
    $ns at $opt(stoptime)     "$cbr(2,0) stop"
    $ns at $opt(starttime)    "$cbr(3,0) start"
    $ns at $opt(stoptime)     "$cbr(3,0) stop"
}


proc finish {} {
    global ns opt outfile
    global mac propagation cbr_sink mac_sink phy_data phy_data_sink channel db_manager propagation
    global node_coordinates
    global ipr_sink ipr ipif udp cbr phy phy_data_sink
    global node_stats tmp_node_stats sink_stats tmp_sink_stats
    if ($opt(verbose)) {
        puts "---------------------------------------------------------------------"
        puts "Simulation summary"
        puts "number of nodes  : $opt(nn)"
        puts "packet size      : $opt(pktsize) byte"
        puts "cbr period       : $opt(cbr_period) s"
        puts "number of nodes  : $opt(nn)"
        puts "simulation length: $opt(txduration) s"
        puts "tx power         : $opt(txpower) dB"
        puts "tx frequency     : $opt(freq) Hz"
        puts "tx bandwidth     : $opt(bw) Hz"
        puts "bitrate          : $opt(bitrate) bps"
        puts "---------------------------------------------------------------------"
    }
    set sum_cbr_throughput     0
    set sum_per                0
    set sum_cbr_sent_pkts      0.0
    set sum_cbr_rcv_pkts       0.0

    for {set i 0} {$i < $opt(nn)} {incr i}  {
		for {set j 0} {$j < $opt(nn)} {incr j} {
            if {$i == 0 && $j != 0} {
			set cbr_throughput          [$cbr($i,$j) getthr]
            set cbr_sent_pkts           [$cbr($i,$j) getsentpkts]
			set cbr_rcv_pkts            [$cbr($i,$j) getrecvpkts]
            set sum_cbr_sent_pkts       [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
            set sum_cbr_rcv_pkts        [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
            set sum_cbr_throughput      [expr $sum_cbr_throughput + $cbr_throughput]
            puts "cbr($i,$j) throughput                    : $cbr_throughput"
            }
		}
        if {$i != 0} {
            set cbr_throughput          [$cbr($i,0) getthr]
            set cbr_sent_pkts           [$cbr($i,0) getsentpkts]
			set cbr_rcv_pkts            [$cbr($i,0) getrecvpkts]
            set sum_cbr_sent_pkts       [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
            set sum_cbr_rcv_pkts        [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
            set sum_cbr_throughput      [expr $sum_cbr_throughput + $cbr_throughput]
            puts "cbr($i,0) throughput                    : $cbr_throughput"
        }
    }
        
    set ipheadersize        [$ipif(1) getipheadersize]
    set udpheadersize       [$udp(1) getudpheadersize]
    set cbrheadersize       [$cbr(1,0) getcbrheadersize]
    
    if ($opt(verbose)) {
        puts "Mean Throughput          : [expr ($sum_cbr_throughput/6)]"
        puts "Sent Packets             : $sum_cbr_sent_pkts"
        puts "Received Packets         : $sum_cbr_rcv_pkts"
        puts "Packet Delivery Ratio    : [expr $sum_cbr_rcv_pkts / $sum_cbr_sent_pkts * 100]"
        puts "IP Pkt Header Size       : $ipheadersize"
        puts "UDP Header Size          : $udpheadersize"
        puts "CBR Header Size          : $cbrheadersize"
        puts "done!"
    }
    
    $ns flush-trace
    close $opt(tracefile)
}

#setUp

$ns at [expr $opt(stoptime) + 250.0]  "finish; $ns halt" 

$ns run

