proc finish {} {

     global ns nf f

     $ns flush-trace

     close $nf

     close $f

     exec nam outEx1.nam &

     exit 0

}