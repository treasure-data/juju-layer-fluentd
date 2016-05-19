#!/bin/bash
set -ex

source charms.reactive.sh

#####################################################################
#
# Basic Functions
# 
#####################################################################

# Version for agent when building from source
FLUENTD_VERSION="0.12.23"
SOFTWARE_CLASS="logging"
SOFTWARE_NAME="fluentd"
TEMPLATE_DIR="/opt/templates"

# Load Configuration
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

#####################################################################
#
# Charm Content
# 
#####################################################################
OS=` echo \`uname\` | tr '[:upper:]' '[:lower:]'`
KERNEL=`uname -r`
MACH=`uname -m`

if [ "${OS}" == "windowsnt" ]; then
    OS=windows
elif [ "${OS}" == "darwin" ]; then
    OS=mac
else
    OS=`uname`
    if [ "${OS}" = "SunOS" ] ; then
        OS=Solaris
        ARCH=`uname -p`
        OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
    elif [ "${OS}" = "AIX" ] ; then
        OSSTR="${OS} `oslevel` (`oslevel -r`)"
    elif [ "${OS}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DISTROBASEDON='RedHat'
            DIST=`cat /etc/redhat-release |sed s/\ release.*//`
            PSEUDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/SuSE-release ] ; then
            DISTROBASEDON='SuSe'
            PSEUDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            DISTROBASEDON='Mandrake'
            PSEUDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
            DISTROBASEDON='Debian'
            if [ -f /etc/lsb-release ] ; then
                DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
                PSEUDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
                REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
            fi
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
        fi
        OS=`echo $OS | tr '[:upper:]' '[:lower:]'`
        DISTROBASEDON=`echo $DISTROBASEON | tr '[:upper:]' '[:lower:]'`
        readonly OS
        readonly DIST
        readonly DISTROBASEDON
        readonly PSEUDONAME
        readonly REV
        readonly KERNEL
        readonly MACH
    fi
fi

# Setting some high level specifics depending on versions
case "$(arch)" in
    "x86_64" | "amd64" )
        ARCH="x86_64"
        ARCH_ALT="amd64"
    ;;
    "ppc64le" | "ppc64el" )
        ARCH="ppc64le"
    ;;
    * )
        juju-log "Your architecture is not supported. Exiting"
        exit 1
    ;;
esac

case "${PSEUDONAME}" in 
    "precise" )
        # LXC_CMD=""
        APT_CMD="apt-get"
        APT_FORCE="--force-yes"

        # This is so hacky but Juju leaves me no choice
        cat >> /etc/profile.d/${SOFTWARE_NAME}.sh << EOF
export BIN_NAME=td-agent
export CONF_DIR=/etc/${BIN_NAME}
export PLUGIN_DIR=${CONF_DIR}/plugin
export LOG_DIR=/var/log/${BIN_NAME}
export PID_DIR=/var/run/${BIN_NAME}
export CONF_FILE=${CONF_DIR}/${BIN_NAME}.conf
EOF

        export BIN_NAME=td-agent
        export CONF_DIR=/etc/${BIN_NAME}
        export PLUGIN_DIR=${CONF_DIR}/plugin
        export LOG_DIR=/var/log/${BIN_NAME}
        export PID_DIR=/var/run/${BIN_NAME}
        export CONF_FILE=${CONF_DIR}/${BIN_NAME}.conf
    ;;
    "trusty" )
        LXC_CMD="$(running-in-container | grep lxc | wc -l)"
        APT_CMD="apt-get"
        APT_FORCE="--force-yes"
        cat >> /etc/profile.d/${SOFTWARE_NAME}.sh << EOF
export BIN_NAME=td-agent
export CONF_DIR=/etc/${BIN_NAME}
export PLUGIN_DIR=${CONF_DIR}/plugin
export LOG_DIR=/var/log/${BIN_NAME}
export PID_DIR=/var/run/${BIN_NAME}
export CONF_FILE=${CONF_DIR}/${BIN_NAME}.conf
EOF

        export BIN_NAME=td-agent
        export CONF_DIR=/etc/${BIN_NAME}
        export PLUGIN_DIR=${CONF_DIR}/plugin
        export LOG_DIR=/var/log/${BIN_NAME}
        export PID_DIR=/var/run/${BIN_NAME}
        export CONF_FILE=${CONF_DIR}/${BIN_NAME}.conf

    ;;
    "xenial" )
        LXC_CMD="$(systemd-detect-virt --container | grep lxc | wc -l)"
        APT_CMD="apt"
        APT_FORCE="--allow-downgrades --allow-remove-essential --allow-change-held-packages"

        cat >> /etc/profile.d/${SOFTWARE_NAME}.sh << EOF
export BIN_NAME=fluent
export CONF_DIR=/etc/${BIN_NAME}
export PLUGIN_DIR=${CONF_DIR}/plugin
export LOG_DIR=/var/log/${BIN_NAME}
export PID_DIR=/var/run/${BIN_NAME}
export CONF_FILE=${CONF_DIR}/${BIN_NAME}.conf
EOF

        export BIN_NAME=fluent
        export CONF_DIR=/etc/${BIN_NAME}
        export PLUGIN_DIR=${CONF_DIR}/plugin
        export LOG_DIR=/var/log/${BIN_NAME}
        export PID_DIR=/var/run/${BIN_NAME}
        export CONF_FILE=${CONF_DIR}/${BIN_NAME}.conf
    ;;
    * )
        juju-log "Your version of Ubuntu is not supported. Exiting"
        exit 1
    ;;
esac

function charm::lib::self_assessment() {
    [ -d /var/lib/juju/agents ] || exit 1
    for FILE in $(find "/var/lib/juju/agents" -name "metadata.yaml")
    do
        CHARM+=" $(cat "${FILE}" | grep 'name' | head -n1 | cut -f2 -d' ')" 
    done
    echo "${CHARM}" | sort | uniq
}

function charm::lib::get_templates() {
    local INSTALL_DIR="$1"

    [ -d "${INSTALL_DIR}" ] && { 
        cd "${INSTALL_DIR}"
        git pull --quiet --force origin master
    } || {
        git clone --quiet --recursive https://github.com/SaMnCo/ops-templates.git "${INSTALL_DIR}"
    }
}

function charm::lib::find_roles() {
    for TARGET in $(charm::lib::self_assessment)
    do
        case "${CHARM}" in 
            ceilometer | cinder | glance | heat | horizon | keystone | neutron* | nova* | openstack-dashboard )
                juju-log "Configuring ${SOFTWARE_NAME} for ${TARGET} (OpenStack)"
                TARGET_LIST+=" ${TARGET} openstack dmesg"
            ;;
            ceph* )
                juju-log "Configuring ${SOFTWARE_NAME} for ${TARGET} (Ceph Storage)"
                TARGET_LIST+=" ${TARGET} dmesg ceph-global"
            ;;
            * )
                juju-log "Configuring ${SOFTWARE_NAME} for ${TARGET} (Generic Solution)"
                TARGET_LIST+=" ${TARGET}"
            ;;
        esac
    done

    echo "${TARGET_LIST}" | sort | uniq 
}

function charm::lib::who_am_i() {
    cat "${JUJU_CHARM_DIR}/metadata.yaml" | grep 'name' | head -n1 | cut -f2 -d' '
}

#####################################################################
#
# Install per architecture
# 
#####################################################################

function all::all::install_from_repo() {
    juju-log "Installing Treasure Data GPG"
    status-set maintenance "Installing Treasure Data GPG"
    curl https://packages.treasuredata.com/GPG-KEY-td-agent | apt-key add - && \
        juju-log "Successfully added GPG Key to apt" || \
        { 
            juju-log "Failed to add GPG key. Exiting"
            exit 1
        }

    juju-log "Installing Software Repositories"
    status-set maintenance "Installing Software Repositories"
    echo "deb http://packages.treasuredata.com/2/ubuntu/${PSEUDONAME}/ ${PSEUDONAME} contrib" | \
        tee /etc/apt/sources.list.d/treasure-data.list

    $APT_CMD update -qq && \
    $APT_CMD upgrade -yqq

    juju-log "Installing Software"
    status-set maintenance "Installing Software"
    $APT_CMD install -yqq ${APT_FORCE} td-agent 

    install -m 0755  -o root -g root \
        ${MYDIR}/../files/usr/local/bin/fluentd-update-config.sh /usr/local/bin/fluentd-update-config.sh

}

function all::all::install_from_source() {
    juju-log "Installing pre-requisites"
    status-set maintenance "Installing pre-requisites"
    ${APT_CMD} install -yqq ${APT_FORCE} bundler

    # Get Fluentd source code and checkout the latest from 0.12 branch
    juju-log "Downloading sources"
    status-set maintenance "Downloading sources"
    [ -d "/opt/${BIN_NAME}" ] || \
        git clone --quiet https://github.com/fluent/fluentd.git /opt/${BIN_NAME}

    cd /opt/${BIN_NAME}
    git checkout tags/v${FLUENTD_VERSION}
    git pull --quiet origin tags/v${FLUENTD_VERSION}

    # Install Fluentd requirements and package the gem
    juju-log "Building from source... "
    status-set maintenance "Building from source..."
    bundle install
    bundle exec rake build

    # Install Fluentd gem
    gem install pkg/`ls -t pkg/`

    juju-log "Installing..."
    status-set maintenance "Installing..."

    # Shortcut to match td-agent naming for fluentd gem
    ln -sf /usr/local/bin/fluentd /usr/sbin/${BIN_NAME}

    # Add System User (ref deb package)
    if ! getent passwd ${BIN_NAME} >/dev/null; then
        adduser --group --system --no-create-home ${BIN_NAME}
    fi

    for FOLDER in "${CONF_DIR}" "${PLUGIN_DIR}" "${CONF_DIR}" "${LOG_DIR}" "${LOG_DIR}/buffer" "${PID_DIR}"
    do
        [ -d "${FOLDER}" ] || mkdir -p "${FOLDER}"
        chown -R ${BIN_NAME} "${FOLDER}"
        chmod 0755 "${FOLDER}"
    done 

    [ -d "/var/log/${BIN_NAME}/buffer/" ]&& \
        chown -R ${BIN_NAME}:${BIN_NAME} /var/log/${BIN_NAME}/buffer/
    [ -d "/tmp/${BIN_NAME}/" ] && \
        chown -R ${BIN_NAME}:${BIN_NAME} /tmp/${BIN_NAME}/
    [ -d "/etc/logrotate.d/" ] && \
        install -m 0644 -o root -g root \
            ${MYDIR}/../files/etc/${BIN_NAME}/logrotate.d/${BIN_NAME}.logrotate /etc/logrotate.d/${BIN_NAME}

    if [ ! -e "/etc/default/${BIN_NAME}" ]; then
  cat > /etc/default/${BIN_NAME} <<EOF
# This file is sourced by /bin/sh from /etc/init.d/${BIN_NAME}
# Options to pass to td-agent
TD_AGENT_OPTIONS=""

EOF
    fi

    install -m 0755 -o root -g root \
        ${MYDIR}/../files/etc/init.d/${BIN_NAME} /etc/init.d/${BIN_NAME}

    if [ -x "/etc/init.d/${BIN_NAME}" ]; then
        if [ ! -e "/etc/init/${BIN_NAME}.conf" ]; then
            update-rc.d ${BIN_NAME} defaults >/dev/null
        fi
        # invoke-rc.d ${BIN_NAME} start || exit $?
    fi
}

function precise::x86_64::install_fluentd() { 
    all::all::install_from_source
}

function trusty::x86_64::install_fluentd() { 
    all::all::install_from_source 
}

function xenial::x86_64::install_fluentd() { 
    all::all::install_from_source
}

function precise::x86_64::install_fluentd() { 
    all::all::install_from_source
}

function trusty::ppc64le::install_fluentd() { 
    all::all::install_from_source
}

function xenial::ppc64le::install_fluentd() { 
    all::all::install_from_source
}

#####################################################################
#
# Management of the agent
# 
# Note: keeping "all_all" because probable changes with upstart/systemd
# 
#####################################################################

# This creates the file structure for template storage
function all::all::start_fluentd() {
    juju-log "Restarting Service ${BIN_NAME}"
    status-set maintenance "Restarting Service ${BIN_NAME}"
    service ${BIN_NAME} start || service ${BIN_NAME} restart
    status-set active "${BIN_NAME} installed and running"
}

function all::all::stop_fluentd() {
    juju-log "Stopping Service ${BIN_NAME}"
    status-set maintenance "Stopping Service ${BIN_NAME}"
    service ${BIN_NAME} stop
    status-set maintenance "${BIN_NAME} installed but not running"
}

function all::all::reload_fluentd() {
    juju-log "Reloading Service ${BIN_NAME}"
    status-set maintenance "Reloading Service ${BIN_NAME}"
    service ${BIN_NAME} reload || service ${BIN_NAME} force-reload
    status-set active "${BIN_NAME} installed and running"
}

#####################################################################
#
# Configuration
# 
#####################################################################

# This creates the file structure for template storage
function all::all::configure_fluentd() {
    # Emulating the structure of Apache vhosts in this context
    for FOLDER in "${CONF_DIR}/conf.d" "${CONF_DIR}/conf.d/enabled"
    do
        [ -d "${FOLDER}" ] || mkdir -p "${FOLDER}"
        chmod 0755 "${FOLDER}"
    done 

    charm::lib::get_templates "${TEMPLATE_DIR}"

    # Copying existing templates 
    ln -sf "${TEMPLATE_DIR}/${SOFTWARE_CLASS}/${SOFTWARE_NAME}" "${CONF_DIR}/conf.d/available"

    # cronjob for fluentd to add configuration
    install -m 0755 -o root -g root \
        ${MYDIR}/../files/usr/local/bin/fluentd-update-config.sh /usr/local/bin/fluentd-update-config.sh

    install -m 0755 -o root -g root \
        ${MYDIR}/../files/etc/cron.d/fluentd /etc/cron.d/fluentd

    sed -i "s,CONF_DIR,${CONF_DIR},g" /etc/cron.d/fluentd

    install -m 0644 -o root -g root \
        "${MYDIR}/../files/etc/fluent/fluent.conf" "/etc/${BIN_NAME}/${BIN_NAME}.conf"

    service cron restart
}

# @hook 'install'
@when_not 'fluentd.installed'
function install_fluentd() {

    # charms.reactive unset_state 'cuda.installed'
    status-set maintenance "Installing fluentd"

    ${PSEUDONAME}::${ARCH}::install_fluentd

    status-set waiting "Now moving to configuration"

    charms.reactive set_state 'fluentd.installed'
}

# @hook 'config-changed'
@when 'fluentd.installed'
@when_not 'fluentd.available'
function config_fluentd() {

    all::all::configure_fluentd
    all::all::start_fluentd

    status-set maintenance "Ready to start"
    charms.reactive set_state 'fluentd.available'


}

@hook 'start'
function start_fluentd() {
    all::all::start_fluentd

    status-set active "fluentd installed and available"
}

reactive_handler_main

