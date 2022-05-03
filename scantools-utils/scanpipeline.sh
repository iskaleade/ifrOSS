#!/bin/sh

# (C) Lisa 2022
# SPDX-License-Identifier: MIT

# lets go
	echo "Which directory should be scanned (please indicate complete path)"
	read -e toBeScanned
	
	printf "\nInfo: Scan results will be stored to $HOME/scan-results \n \n"
	
	cd "$toBeScanned"
	nameOfScannedProduct=$(basename $toBeScanned)
	
	echo "What is the location of your scantools? (scancode-toolkit, opossumUI, opossum.lib.hs)? (e.g. /home/<user>/scantools - the directory should only contain one version of each tool)"
	read -e toolDirectory 
	
	# check if ~/Tools/scancode-toolkit or similar exists: 	
	scancodeLocation=$(find "$toolDirectory" -name "scancode-toolkit*" -type d) 

	if [ "$scancodeLocation" != ""  ]; then 
  		echo "Scancode installation found"
 	else 
 		echo "No Scancode installation found. Aborting... "
 		exit
 	fi

	
	#check if ~/Tools/Opossum/opossum-lib.hs-main/ or similar exists
	opossumLocation=$(find "$toolDirectory" -name "opossum.lib.hs*" -type d)
	
	if [ "$opossumLocation" != "" ]; then
		echo "Opossum converter tool found."
	else
		echo "Please make sure opossum-lib.hs-main directory exists in your tool directory. Aborting..."
		exit
	fi

	#check if opossumUI is installed
	opossumUILocation=$(find "$toolDirectory" -name "OpossumUI-for-linux.AppImage" -type f)
	
	if [ "$opossumUILocation" != "" ]; then 
		echo "OpossumUI found"
	else 
		echo "OpossumUI not found. I will continue and create scan results, but you will most likely have to open OpossumUI yourself."
	fi

echo "use ORT? (not recommended yet, requires ORT docker installation, highly unstable... :D) (y/n)"
read go
if [[ "$go" == "y" ]]; then 
	

	# check if ORT is installed
	result=$( sudo docker images -q ort )

	if [[ -n "$result" ]]; then 		
		echo "ORT docker image found"
	else 
		echo "no ORT-docker image found - is theORT-Docker-Image installed? (y/n)"
		read imageInstalled
		if [[ "$imageInstalled" == "y" ]]; then 
			echo "OK, proceed at own risk..."
		else
			echo "Please install image before proceeding!"
			exit
		fi
	fi
	
	echo "name: $nameOfScannedProduct - starting analysis..."
	ANALYZED=0
	if [ -d "$HOME/ort-home/$nameOfScannedProduct/analyzer/" ]; then 
		echo "It looks like you analyzed this product before. Do you want to repeat analysis or proceed directly to the ORT downloader?? (y = repeat analysis, n = proceed to downloader)"
		read decision
		
		if [[ "$decision" == "n" ]]; then ANALYZED=1
		
		else sudo rm -R $HOME/ort-home/$nameOfScannedProduct/analyzer
		
		fi
	fi
	
	if [[ "$ANALYZED" == "0" ]]; then 
		sudo docker run -e ORT_CONFIG_DIR=/ort-home/.ort -e ORT_DATA_DIR=/ort-home/.ort --rm -v $HOME/ort-home/:/ort-home -v $PWD/:/project ort --info analyze -f JSON -i /project -o /ort-home/$nameOfScannedProduct/analyzer
		if [ $? -eq 0 ]; then
			echo "Analyzer run succesful."
		else 
			echo "Sorry, something went wrong. Aborting..."
		exit
		fi
	fi
	
	DOWNLOADED=0
	if [ -d "$HOME/ort-home/$nameOfScannedProduct/downloader/" ]; then 
		echo "It looks like you already used the ORT downloader on this product. Download again or proceed to scan? (y = repeat download, n = proceed to scan)"
		read decision
		
		if [[ "$decision" == "n" ]]; then DOWNLOADED=1
		fi
	fi
	
	if [[ "$DOWNLOADED" == "0" ]]; then 
	
		echo "ORT downloader will now download dependencies. This may take a while. However, you can proceed without dependencies if you like. Download dependencies? (y/n)"
		read getDependencies
		
		if [[ "$getDependencies" == "y" ]]; then
		
			sudo docker run -e ORT_CONFIG_DIR=/ort-home/.ort -e ORT_DATA_DIR=/ort-home/.ort --rm -v $HOME/ort-home/:/ort-home -v $PWD/:/project ort --info download -i /ort-home/$nameOfScannedProduct/analyzer/analyzer-result.json -o /ort-home/$nameOfScannedProduct/downloader
			if [ $? -eq 0 ]; then
				echo "Downloads done."
			else
				echo "Sorry, something went wrong. Aborting..."
			exit
			fi
		fi
	fi
	echo "Proceeding with the scan using scancode."	
	#to do: scan using ORT, then use reporter to generate opossum output

fi
	
	SCANNED=0
	if [[ -f "$HOME/scan-results/$nameOfScannedProduct/scancode_output.json" ]]; then 
		echo "I found previous scan results. Should the scan be repeated? (y/n)" 
		read decision
		
		if [[ "$decision" == "n" ]]; then SCANNED=1
		fi
	fi
	
	if [[ "$SCANNED" == "0" ]]; then
		mkdir -p $HOME/scan-results/$nameOfScannedProduct/scancode 
		$scancodeLocation/scancode -clpieu --license-text -n 8 --ignore "analyzer-result.json" --json-pp $HOME/scan-results/$nameOfScannedProduct/scancode/scancode_output_$nameOfScannedProduct.json $toBeScanned 
		
		
	fi
	
	# convert scan results to Opossum format: 
	echo "Now: Converting ScanCode-JSON to Opossum format."
	mkdir -p $HOME/scan-results/$nameOfScannedProduct/opossum

	$opossumLocation/opossum-lib-exe.sh --scancode $HOME/scan-results/$nameOfScannedProduct/scancode/scancode_output_$nameOfScannedProduct.json > $HOME/scan-results/$nameOfScannedProduct/opossum/scancode_opossum_$nameOfScannedProduct.json
	
	if [ $? -eq 0 ]; then
		echo "Conversion done."
	else
		echo "Sorry, something went wrong. Aborting..."
		exit
	fi
	
	# starting Opossum
	# find opossum UI
	
	echo "I will now try to start OpossumUI."
	
	
	if [ "$opossumUILocation" != "" ]; then 
		$opossumUILocation -i $HOME/scan-results/$nameOfScannedProduct/opossum/scancode_opossum_$nameOfScannedProduct.json
	else 
		echo "Unfortunately I couldn't find your OpossumUI installation. You may proceed and open it yourself, scan results are stored to $HOME/scan-results"
	fi
