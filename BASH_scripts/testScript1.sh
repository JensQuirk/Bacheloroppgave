#!/bin/bash


#Gets values from parameters
seed=${1}
pPeriod=${2}
packetSize=${3}
echo $seed

#Sources the DESERT environment variable
source ~/DESERT_Underwater/DESERT_buildCopy_LOCAL/environment

#Sets path to ns, tcl-script and simulation output directory
nsPATH="/home/yonx/DESERT_Underwater/DESERT_buildCopy_LOCAL/bin/ns"
tclPATH="/home/yonx/Bacheloroppgave/Sims/Test/dacapStaticScenario.tcl"
outputPATH="/home/yonx/Bacheloroppgave/SimResults/DACAPSimulations"

#Creates required directories if they don't already exist
if [ ! -d /home/yonx/Bacheloroppgave/SimResults ]; then
	mkdir /home/yonx/Bacheloroppgave/SimResults
fi
if [ ! -d /home/yonx/Bacheloroppgave/SimResults/DACAPSimulations ]; then
	mkdir /home/yonx/Bacheloroppgave/SimResults/DACAPSimulations
fi

datafile="${outputPATH}/dacapTestSimData.csv"
echo -e "Poisson Period,Packet Size,Mean Throughput,Packet Delivery Ratio" > $datafile

#Run simulations with different cbr poisson periods
for poissonPeriod in 40 60 80 100 150 200
do
	#Sets name of output files
	outfile="${outputPATH}/dacapTestSim_${poissonPeriod}.txt"
	#datafile="${outputPATH}/dacapTestSimData_${poissonPeriod}.csv"
	
	#Output to readable file
	echo -e "DACAP\nseed: ${seed}\ncbr poisson period: ${poissonPeriod}\npacket size: ${packetSize}" > $outfile
	$nsPATH $tclPATH $seed $poissonPeriod $packetSize | grep 'Mean Th\|Packet Del' >> $outfile
	echo -e "\n" >> $outfile

	#Output to csv file
	#echo -e "Poisson Period,Packet Size,Mean Throughput,Packet Delivery Ratio" > $datafile
	meanThr=$(cat $outfile | grep 'Mean Th' )
	meanThr=$(echo "${meanThr}" | grep -oE '[0-9]+([.][0-9]+)?')
	PDR=$(cat $outfile | grep 'Packet Del' )
	PDR=$(echo "${PDR}" | grep -oE '[0-9]+([.][0-9]+)?')
	echo "${poissonPeriod},$packetSize,${meanThr},${PDR}" >> $datafile
	echo -e "\n" >> $datafile
done
