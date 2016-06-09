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

function charm::lib::self_assessment() {
	[ -d /var/lib/juju/agents ] || exit 1
	for FILE in $(find "/var/lib/juju/agents" -name "metadata.yaml")
	do
		CHARM+=" $(cat "${FILE}" | grep 'name' | head -n1 | cut -f2 -d' ')" 
	done
	echo "${CHARM}" | sort | uniq
}

function charm::lib::find_roles() {
    for TARGET in $(charm::lib::self_assessment)
    do
        case "${TARGET}" in 
            ceilometer | cinder | glance | heat | horizon | keystone | neutron* | nova* | openstack-dashboard )
                echo "Configuring ${SOFTWARE_NAME} for ${TARGET} (OpenStack)"
                TARGET_LIST+=" ${TARGET} openstack dmesg"
            ;;
            ceph* )
                echo "Configuring ${SOFTWARE_NAME} for ${TARGET} (Ceph Storage)"
                TARGET_LIST+=" ${TARGET} dmesg ceph-global"
            ;;
            "*fluent*" )
                echo "Not monitoring myself"
            ;;
            mysql | mariadb | percona-cluster | galera* )
                echo "Using standard MySQL for ${TARGET}"
                TARGET_LIST+=" mysql"
            ;;
            * )
                echo "Configuring ${SOFTWARE_NAME} for ${TARGET} (Generic Solution)"
                TARGET_LIST+=" ${TARGET}"
            ;;
        esac
    done

    echo "${TARGET_LIST}" | sort | uniq 
}

function all::all::add_input_sources() {
    local SOURCE_LIST="$(charm::lib::find_roles)"

    for SOURCE in ${SOURCE_LIST}
    do
        find "${AVAILABLE_FOLDER}"/ \
            -name "input_${SOURCE}.conf" \
            -exec sudo ln -sf "{}" "${ENABLED_FOLDER}/input_${SOURCE}.conf" \;
    done
}

function all::all::remove_input_sources() {
    sudo rm -rf "${ENABLED_FOLDER}/input*"
}

function all::all::restart_agent() {
	sudo service ${SOFTWARE_NAME} restart || { sudo service ${SOFTWARE_NAME} stop; sudo service ${SOFTWARE_NAME} start; }
}

# Updating template list
charm::lib::get_templates "${TEMPLATE_DIR}"

# Removing all sources
all::all::remove_input_sources

# Creating all sources
all::all::add_input_sources

# Restart agent 
all::all::restart_agent

