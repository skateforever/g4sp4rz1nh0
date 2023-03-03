#!/bin/bash

# Kill the previous instances running.
kill_g4sp4rz1nh0_execution

# Create directory and checking if the required structure is ready
create_initial_directory_structure_files

# Creating the initial haproxy service configuration
haproxy_create_file

# Creating the backend to tor instances
haproxy_tor_backend

# Start the TOR instances 
# Independent of the list of accepted countries
if [ "${MY_COUNTRY_LIST}" != "RANDOM" ]; then
    # If you defined a specific list of countries put this countries in a in a RANDOM order.
    MY_COUNTRY_LIST="$(echo "${MY_COUNTRY_LIST}" | sed 's|,|\n|g' | sort -R)"
    # Call the declared function
    boot_tor_per_country
else
    # If you do not specify a list of countries. The script will select
    # random countries from your accepted countries list.
    MY_COUNTRY_LIST="FIRST_EXECUTION"
    # Call the declared function
    random_country
fi

# Save the list of current countries. The watchdog script uses this list to
# select the instance which will change the country during the execution.
echo "${MY_COUNTRY_LIST}" > "${TOR_DIR_TEMP_FILES}/current_country_list.txt"

TOR_TOTAL_INSTANCES=$((COUNTRIES * TOR_INSTANCES))

# After boot the TOR instances finish the configuration of the script which will force a new circuit for all running instances.
# Renew all TOR circuits using a random order.
echo "#!/bin/bash
sleep "${TOR_TOTAL_INSTANCES}"
while :; do" > "${TOR_DIR_TEMP_FILES}/force_new_circuit.sh"
sort -R "${TOR_DIR_TEMP_FILES}/force_new_circuit_temp.txt" | \
    sed 's/expect/    expect/ ; s/null/null\n    sleep 10/' >> "${TOR_DIR_TEMP_FILES}/force_new_circuit.sh"
echo "done" >> "${TOR_DIR_TEMP_FILES}/force_new_circuit.sh"

rm -rf "${TOR_DIR_TEMP_FILES}/force_new_circuit_temp.txt"

# Starting the script to force the new circuits in background.
/bin/bash "${TOR_DIR_TEMP_FILES}/force_new_circuit.sh" > /dev/null 2>&1 &

# Creating the backend to privoxy instances
haproxy_privoxy_backend

# Start the Privoxy instances
boot_privoxy_instances

# HAProxy startup
haproxy_startup

# Show the status screen while loading the TOR INSTANCES
echo -e "\nTips:"
echo "     1) Wait until all yours (${TOR_CURRENT_INSTANCE}) requested TOR instances be ready."
echo " "
echo "     2) You can monitor the health of your TOR INSTANCES using the following link:"
echo "        URL:             http://${HAPROXY_LISTEN_ADDR}:${HAPROXY_MASTER_PROXY_STAT_PORT}${HAPROXY_MASTER_PROXY_STAT_URI}" | tee -a "${g4sp4rz1nh0_access_log}"
echo "        User ID:         ${USER_ID}" | tee -a "${g4sp4rz1nh0_access_log}"
echo "        Random Password: ${HAPROXY_MASTER_PROXY_STAT_PWD}" | tee -a "${g4sp4rz1nh0_access_log}"
echo " "
echo "        DO NOT OPEN THIS FOR YOUR LOCAL NETWORK!"
echo " "
echo "     3) Set the: "
echo "          3.1) HTTP proxy http://${HAPROXY_LISTEN_ADDR}:${HAPROXY_MASTER_PROXY_PORT} in your web browser and enjoy!" | tee -a "${g4sp4rz1nh0_access_log}"
echo "          3.2) Socks proxy socks5://${HAPROXY_LISTEN_ADDR}:${HAPROXY_MASTER_SOCKS_PORT} in your web browser and enjoy!" | tee -a "${g4sp4rz1nh0_access_log}"
echo " "
echo "=============================================================================================================="
echo "Number of countries        : ${COUNTRIES}"
echo "Instances per country      : ${TOR_INSTANCES}"
echo "Total of TOR instances     : ${TOR_TOTAL_INSTANCES}"
echo "TOR Relay is enforcing the : ${COUNTRY_LIST_CONTROLS}"
echo "-"
echo "The list of selected countries are:"
echo "${MY_COUNTRY_LIST}" | sed 's/$/,/g' | sed ':a;N;s/\n//g;ta'
echo "=============================================================================================================="
echo " "

sleep 2

sed -i 's/3\..) //' "${g4sp4rz1nh0_access_log}"
sed -i "s/^[[:blank:]]*//" "${g4sp4rz1nh0_access_log}"

# Updating the status of the TOR INSTANCE ready to use.
READY=0
COUNT_TIME="${TOR_TOTAL_INSTANCES}"
POSITION=$(( "${COUNTRIES}" + 40 ))
while [ "${READY}" -lt "${TOR_TOTAL_INSTANCES}" ]; do
    READY=$(grep -o 'Bootstrapped 100%' "${TOR_DIR_TEMP_FILES}"/tor*/tor_log_* 2> /dev/null| wc -l)
    tput cup ${POSITION} 0
    echo -n "We have (${READY}) TOR instances READY to be used from total of (${TOR_TOTAL_INSTANCES}) requested instances. Please wait... "
    sleep 3
    (( COUNT_TIME -= 1 ))
    if [ "${COUNT_TIME}" -eq 0 ]; then
        if [ "${RELEASE_TOR_INSTANCE_READY_COUNT}" == "yes" ]; then
            echo -e "Stopped!\n"
            echo "We release the count of TOR instance to can use the others nodes."
            echo "The incomplete boot process of TOR instance, probably will be reloaded."
            break
        else
            echo "Fail!"
            echo -e "\nIt was not possible to initialize all the instances of TOR, ending the execution of g4sp4rz1nh0."
            # Kill the previous instances running.
            kill_g4sp4rz1nh0_execution
            exit 1
        fi
    fi
done
[[ ${COUNT_TIME} -ne 0 ]] && echo "Done!"

# Call the background function that changes the COUNTRY on the fly...
if [ "${CHANGE_COUNTRY_ONTHEFLY}" = "yes" ]; then
    #Saving the inicial user settings.
    echo -e "TOR_INSTANCES=\"${TOR_INSTANCES}\"\nCOUNTRIES=\"${COUNTRIES}\"\nCOUNTRY_LIST_CONTROLS=\"${COUNTRY_LIST_CONTROLS}\"" \
        > "${TOR_DIR_TEMP_FILES}/initial_user_settings.txt"
    if [ -x "${g4sp4rz1nh0_PATH}/functions/999_let_the_g4sp4rz1nh0_play.sh" ]; then
        # Change the COUNTRY of the TOR INSTANCE running.
	    /bin/bash "${g4sp4rz1nh0_PATH}/functions/999_let_the_g4sp4rz1nh0_play.sh" &
    else
        echo "The responsable script to change Country of TOR Instance doesn't exist!"
        exit 1
    fi
fi
