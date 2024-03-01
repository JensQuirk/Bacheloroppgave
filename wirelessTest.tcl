#initialize variables
set val(chan)   Channel/WirelessChannel     ;#Channel Type
set val(prop)   Propagation/TwoRayGround    ;#radio-propogation model
set val(netif)  Phy/WirelessPhy             ;#network interface type
set val(mac)    Mac/802_11                  ;#Mac type
set val(ifq)    Queue/DropTail/PriQueue     ;#interface queue type
set val(ll)     ll                          ;#link layer type
set val(ant)    Antenna/OmniAntenna         ;#antenna model
set val(ifqlen) 50                          ;#max packet in ifq
set val(nn)     2                           ;#number of mobilenodes
set val(rp)     DSDV                        ;#routing protocol
set val(x)      500
set val(y)      500