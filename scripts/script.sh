#!/bin/bash

#Executing this script reads data from standard input and directly configures
#the code specified in configure_path and optionally calls the python script
#specified in cbs_path

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

declare -A dict
dict=([21]="FTP" [22]="SSH" [80]="HTTP" [139]="SMB" [443]="HTTPS" [3389]="RDP")

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
	echo -e "[EXECUTING] chainnetwork-random.ipynb ..."
	sleep 2
	python3 -m notebook $RANDOM_PATH
}

#Execute DQL + Random runner code on host machine
execute_runner() {
	echo -e "[EXECUTING] runner.py ..."
	sleep 2
	python3 $RUNNER_PATH --training_episode_count $TRAINING_EPISODE_COUNT --eval_episode_count $EVAL_EPISODE_COUNT --iteration_count $ITERATION_COUNT --rewardplot_with $REWARDPLOT_WITH --chain_size=$CHAIN_SIZE --ownership_goal $OWNERSHIP_GOAL
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
		#modify to accept multiple
		if [ $i = 1 ]; then
			var=${arr[1]}
			IFS=',' read -r -a temp <<< "$var"
			str=""

			for i in ${temp[@]}; do
				protocol=$dict[$i]
				#Check protocol validity
				if [$protocol != ""]; then
					str+="m.ListeningService(\"$protocol\"), "
				fi
			done
		
			arr[1]=$str
		fi
		
		#Firewall Configuration
		#modify to accept multiple
		if [ $i = 3 ]; then
			var=${arr[3]}
			IFS=',' read -r -a temp <<< "$var"
			str=""
			
			for i in ${temp[@]}; do
				protocol=$dict[$i]
				#Check protocol validity
				if [$protocol != ""]; then
					str+="m.FirewallRule(\"$protocol\", m.RulePermission.BLOCK), "
				fi
			done
		
			arr[3]="incoming=["+$str+"], outgoing=DEFAULT_ALLOW_RULES"
		
		fi

		#Vulnerabilities Configuration
		#if [ $i = 4 ]; then
		#fi

		#Replacement of data
		perl -0777 -i -pe "s/CONFIGURE_DATA/${arr[$i]}/" $CHAINPATTERN_PATH
		
		#Increment i to loop over next iteration
		i=$((i+1))
	done
	
	execute_runner
}

start