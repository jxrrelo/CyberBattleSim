#!/bin/bash

#Executing this script reads data from standard input and directly configures
#the code specified in CHAINPATTERN_PATH and optionally calls the python script
#specified in RUNNER_PATH

#info.txt format
#<NODE_ID>:<SERVICES>:<PROPERTIES>:<INCOMING FIREWALL>:<OUTGOING FIREWALL>
#info.txt example
#"StartNode":443, 22=password:"Windows", "Win10", "Win10Patched":22, 80 

#0 - NODE_ID: identifier[1]
#1 - SERVICES: protocol[0...*], credentials[1]
#2 - PROPERTIES: identifier[0...*]
#3 - FIREWALL CONFIGURATION: incoming[0...*], outgoing[0...*]
#4 - VULNERABILITIES: name[0...*]=>type, outcome, cost
#5 - VALUE: value [1]

#Global constants init
RANDOM_PATH="/home/osboxes/CyberBattleSim/notebooks/chainnetwork-random.ipynb"
RUNNER_PATH="/home/osboxes/CyberBattleSim/cyberbattle/agents/baseline/run.py"
CHAINPATTERN_PATH="/home/osboxes/CyberBattleSim/cyberbattle/samples/chainpattern/chainpattern.py"

declare -A ports
ports=(	[21]="FTP" \
		[22]="SSH" \
		[23]="TELNET" \
		[25]="SMTP" \
		[80]="HTTP" \
		[139]="SMB" \
		[161]="SNMP" \
		[443]="HTTPS" \
		[3389]="RDP" )

NUM_ARGS=5
TRAINING_EPISODE_COUNT=10
EVAL_EPISODE_COUNT=10
ITERATION_COUNT=100
REWARDPLOT_WITH=80
CHAIN_SIZE=10
OWNERSHIP_GOAL=1.0

#Global variables init
line="."

#Execute random code on host machine
function execute_random {
	printf "[EXECUTING] chainnetwork-random.ipynb ...\n\n"
	sleep 2
	python3 -m notebook $RANDOM_PATH
}

#Execute DQL + Random runner code on host machine
function execute_runner {
	printf "[EXECUTING] runner.py ...\n\n"
	sleep 2
	python3 $RUNNER_PATH \
	--training_episode_count $TRAINING_EPISODE_COUNT \
	--eval_episode_count $EVAL_EPISODE_COUNT \
	--iteration_count $ITERATION_COUNT \
	--rewardplot_with $REWARDPLOT_WITH \
	--chain_size=$CHAIN_SIZE \
	--ownership_goal $OWNERSHIP_GOAL
}

#Handler for Services field
function services_handler {
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

#Handler for Firewall incoming field
function firewall_in_handler {
	var=${arr[3]}
	IFS=', ' read -r -a temp <<< "$var"
	str=""
	
	for j in "${temp[@]}"; do
		protocol=${ports[$j]}
		#Check protocol validity
		if [ $protocol ]; then
			str+="m.FirewallRule(\"$protocol\", m.RulePermission.ALLOW), "
		fi
	done

	arr[3]="incoming=[$str]"
}

#Handler for Firewall outgoing field
function firewall_out_handler {
	var=${arr[4]}
	IFS=', ' read -r -a temp <<< "$var"
	str=""
	
	for j in "${temp[@]}"; do
		protocol=${ports[$j]}
		#Check protocol validity
		if [ $protocol ]; then
			str+="m.FirewallRule(\"$protocol\", m.RulePermission.ALLOW), "
		fi
	done

	arr[4]="outgoing=[$str]"
}

#Handler for Vulnerabilities field
function vuln_handler {
	var=${arr[5]}
	IFS=', ' read -r -a temp <<< "$var"
	str=""
}

#Entry point
function start {
	#Read from stdin
	while [ "$line" ]; do
		read line
		i=0
		#String manipulate input and parse as array
		IFS=':' read -r -a arr <<< "$line"

		#Iterate through and replace relevant fields
		while [ $i -ne $NUM_ARGS ]; do

			#Manage Configurations
			case $i in
				1) 	#Services Configuration
					services_handler $arr
					;;
				3)	#Firewall Configuration
					firewall_in_handler $arr
					;;
				4)
					#Firewall Configuration
					firewall_out_handler $arr
					;;
				5)	#Vulnerabilities Configuration
					vuln_handler $arr
					;;
			esac

			#Replacement of data in chainpattern.py
			perl -0777 -i -pe "s/CONFIGURE_DATA/${arr[$i]//\//\\/}/" $CHAINPATTERN_PATH
			#sed -i "0,/CONFIGURE_DATA/s//${arr[$i]//\//\\/}/" $CHAINPATTERN_PATH

			#Increment i to loop over next iteration
			i=$((i+1))
		done
	done	
	execute_runner
}

start