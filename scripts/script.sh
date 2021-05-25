#!/bin/bash

#Executing this script reads data from standard input and directly configures
#the code specified in CHAINPATTERN_PATH and optionally calls the python script
#specified in RUNNER_PATH

#echo "[-] Establishing connection..."
#echo "[-] Connection established successfully with host"

#0 - NODE_ID
#1 - SERVICES
#2 - PROPERTIES
#3 - FIREWALL CONFIGURATION
#4 - VULNERABILITIES
#5 - VALUE

#Constants init
RANDOM_PATH="/home/osboxes/CyberBattleSim/notebooks/chainnetwork-random.ipynb"
RUNNER_PATH="/home/osboxes/CyberBattleSim/cyberbattle/agents/baseline/run.py"
CHAINPATTERN_PATH="/home/osboxes/CyberBattleSim/cyberbattle/samples/chainpattern/chainpattern.py"

declare -A ports
ports=([21]="FTP" [22]="SSH" [80]="HTTP" [139]="SMB" [443]="HTTPS" [3389]="RDP")

TRAINING_EPISODE_COUNT=10
EVAL_EPISODE_COUNT=10
ITERATION_COUNT=100
REWARDPLOT_WITH=80
CHAIN_SIZE=10
OWNERSHIP_GOAL=1.0

#Variables init
i=0
numArgs=4

#Execute random code on host machine
execute_random() {
	printf "[EXECUTING] chainnetwork-random.ipynb ...\n\n"
	sleep 2
	python3 -m notebook $RANDOM_PATH
}

#Execute DQL + Random runner code on host machine
execute_runner() {
	printf "[EXECUTING] runner.py ...\n\n"
	sleep 2
	python3 $RUNNER_PATH --training_episode_count $TRAINING_EPISODE_COUNT --eval_episode_count $EVAL_EPISODE_COUNT --iteration_count $ITERATION_COUNT --rewardplot_with $REWARDPLOT_WITH --chain_size=$CHAIN_SIZE --ownership_goal $OWNERSHIP_GOAL
}

#Handler for Services field
services_handler() {
	declare -A creds
	var=${arr[1]}
	IFS=', ' read -r -a svcs <<< "$var"
	str=""

	for svc in "${svcs[@]}"; do
		IFS='=' read -r -a temp <<< "$svc"
		port=${temp[0]}
		cred=${temp[1]}
		if [ $cred ]; then
			creds[portNum]=$cred
		fi
		protocol=${ports[$port]}

		#Check protocol validity
		if [ $protocol ]; then
			str+="m.ListeningService(\"$protocol\""
			if [ $cred ]; then
				str+=", allowedCredentials=[\"$cred\"]),"
			else
				str+="), "
			fi
		fi
	done

	arr[1]=$str
}

#Handler for Firewall field
firewall_handler() {
	var=${arr[3]}
	IFS=', ' read -r -a temp <<< "$var"
	str=""
	
	for j in "${temp[@]}"; do
		protocol=${ports[$j]}
		#Check protocol validity
		if [ -z $protocol ]; then
			str+="m.FirewallRule(\"$protocol\", m.RulePermission.BLOCK), "
		fi
	done

	arr[3]="incoming=[$str], outgoing=DEFAULT_ALLOW_RULES"
}

#Handler for Vulnerabilities field
vuln_handler() {
	var=${arr[4]}
	IFS=', ' read -r -a temp <<< "$var"
	str=""
}

#Entry point
start() {
	#Read from stdin
	read line
	#String manipulate input and parse as array
	IFS=':' read -r -a arr <<< "$line"

	#Iterate through and replace relevant fields
	while [ $i -ne $numArgs ]; do
		#Services Configuration
		if [ $i = 1 ]; then
			services_handler $arr
		fi
		
		#Firewall Configuration
		if [ $i = 3 ]; then
			firewall_handler $arr
		fi

		#Vulnerabilities Configuration
		if [ $i = 4 ]; then
			vuln_handler $arr
		fi

		#Replacement of data
		perl -0777 -i -pe "s/CONFIGURE_DATA/${arr[$i]}/" $CHAINPATTERN_PATH
		
		#Increment i to loop over next iteration
		i=$((i+1))
	done
	
	execute_runner
}

start