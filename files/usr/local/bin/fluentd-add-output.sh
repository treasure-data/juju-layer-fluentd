#!/bin/bash

CONF_DIR=$1
AVAILABLE_FOLDER=${CONF_DIR}/conf.d/available
ENABLED_FOLDER=${CONF_DIR}/conf.d/enabled

SOFTWARE_CLASS="logging"
SOFTWARE_NAME="$(echo ${CONF_DIR} | rev | cut -f1 -d "/" | rev)"
TEMPLATE_DIR="/opt/templates"

function charm::lib::get_templates() {
	local INSTALL_DIR="$1"

	[ -d "${INSTALL_DIR}" ] && { 
		cd "${INSTALL_DIR}"
		sudo git pull --quiet --force origin master 
	} || {
		sudo git clone --quiet --recursive https://github.com/SaMnCo/ops-templates.git "${INSTALL_DIR}"
	}
}

function all::all::add_output_plugin() {
    local PLUGIN_ID=$1
    shift
    local PLUGIN_HOST=$1

    find ${AVAILABLE_FOLDER} -type d -name "output_${PLUGIN_ID}" \
        -exec "{}/install.sh" \; \
        -exec cp -f "{}/output_${PLUGIN_ID}.conf" "${ENABLED_FOLDER}/"

    sed -i -e s|PLUGIN_HOST|"${PLUGIN_HOST}"|g \
        "${ENABLED_FOLDER}/output_${PLUGIN_ID}.conf"

        # -e s|PLUGIN_PORT|"${PLUGIN_PORT}"|g \
}

function all::all::remove_output_plugin() {
    local PLUGIN_ID=$1
    sudo rm -rf "${ENABLED_FOLDER}/output_${PLUGIN_ID}.conf"
}

function all::all::restart_agent() {
	sudo service ${SOFTWARE_NAME} restart || { sudo service ${SOFTWARE_NAME} stop; sudo service ${SOFTWARE_NAME} start; }
}

# Now processing options 
getopt --test > /dev/null
[[ $? != 4 ]] && die "I’m sorry, `getopt --test` failed in this environment."

SHORT=h:p::
LONG=host:plugin::

PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
if [[ $? != 0 ]]; then
    exit 2
fi
eval set -- "$PARSED"

while true; do
    case "$1" in
        -h|--host)
            PLUGIN_HOSTS="$2"
            shift
            shift
            ;;
        -p|--plugin)
            PLUGIN="$2"
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# != 0 ]]; then
    echo "$0: usage: bootstrap.sh -p plugin_name -h host1:port1[,host2:port2..]"
    exit 4
fi

# Testing validity of call
[ "${PLUGIN_HOSTS}x" = "x" ] && { echo "Usage: bootstrap.sh -p plugin_name -h host1:port1[,host2:port2..]"; exit 1 }
[ "${PLUGIN}x" = "x" ] && { echo "Usage: bootstrap.sh -p plugin_name -h host1:port1[,host2:port2..]"; exit 1 }

# Updating template list
charm::lib::get_templates "${TEMPLATE_DIR}"

# Removing all sources
all::all::remove_output_plugin "${PLUGIN}"

# Creating all sources
all::all::add_output_plugin "${PLUGIN}" "${PLUGIN_HOSTS}"

# Restart agent 
all::all::restart_agent

