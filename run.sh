#!/bin/bash
RED='\e[1;31m'
GREEN='\e[1;32m'
RESET='\e[0m'

TICK="\\r[${GREEN}✓${RESET}]"
CROSS="\\r[${RED}✗${RESET}]"
INFO="\\r[i]"
DEPENDENCIES=(ansible)

check_dependencies ()
{
	echo -ne "${INFO} Checking for dependencies..."
	for DEPENDENCY in "${DEPENDENCIES[@]}"
	do
		command -v "${DEPENDENCY}" > /dev/null
		EXIT_CODE=$?
		if [ $EXIT_CODE -ne 0 ]; then
			echo -e "${CROSS} ${DEPENDENCY} is not installed or cannot be found on this system"
			exit $EXIT_CODE
		fi
	done
	echo -e "${TICK}"
}

check_dependencies
echo -e "Running Playbook..."
ansible-playbook "$1" -i inventory.yaml
