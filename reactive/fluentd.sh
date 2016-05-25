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
# Assessments
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
                PSEUDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }' | tr '[:upper:]' '[:lower:]'`
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

        # This is hacky. Eventually we should remove the packaging that don't respect naming
        cat >> /etc/profile.d/${SOFTWARE_NAME}.sh << EOF
export FLUENT_BIN_NAME=fluent
export FLUENT_CONF_DIR=/etc/${FLUENT_BIN_NAME}
export FLUENT_PLUGIN_DIR=${FLUENT_CONF_DIR}/plugin
export FLUENT_LOG_DIR=/var/log/${FLUENT_BIN_NAME}
export FLUENT_PID_DIR=/var/run/${FLUENT_BIN_NAME}
export FLUENT_CONF_FILE=${FLUENT_CONF_DIR}/${FLUENT_BIN_NAME}.conf
EOF

        export FLUENT_BIN_NAME=fluent
        export FLUENT_CONF_DIR=/etc/${FLUENT_BIN_NAME}
        export FLUENT_PLUGIN_DIR=${FLUENT_CONF_DIR}/plugin
        export FLUENT_LOG_DIR=/var/log/${FLUENT_BIN_NAME}
        export FLUENT_PID_DIR=/var/run/${FLUENT_BIN_NAME}
        export FLUENT_CONF_FILE=${FLUENT_CONF_DIR}/${FLUENT_BIN_NAME}.conf
    ;;
    "trusty" )
        LXC_CMD="$(running-in-container | grep lxc | wc -l)"
        APT_CMD="apt-get"
        APT_FORCE="--force-yes"
        cat >> /etc/profile.d/${SOFTWARE_NAME}.sh << EOF
export FLUENT_BIN_NAME=fluent
export FLUENT_CONF_DIR=/etc/${FLUENT_BIN_NAME}
export FLUENT_PLUGIN_DIR=${FLUENT_CONF_DIR}/plugin
export FLUENT_LOG_DIR=/var/log/${FLUENT_BIN_NAME}
export FLUENT_PID_DIR=/var/run/${FLUENT_BIN_NAME}
export FLUENT_CONF_FILE=${FLUENT_CONF_DIR}/${FLUENT_BIN_NAME}.conf
EOF

        export FLUENT_BIN_NAME=fluent
        export FLUENT_CONF_DIR=/etc/${FLUENT_BIN_NAME}
        export FLUENT_PLUGIN_DIR=${FLUENT_CONF_DIR}/plugin
        export FLUENT_LOG_DIR=/var/log/${FLUENT_BIN_NAME}
        export FLUENT_PID_DIR=/var/run/${FLUENT_BIN_NAME}
        export FLUENT_CONF_FILE=${FLUENT_CONF_DIR}/${FLUENT_BIN_NAME}.conf
    ;;
    "xenial" )
        LXC_CMD="$(systemd-detect-virt --container | grep lxc | wc -l)"
        APT_CMD="apt"
        APT_FORCE="--allow-downgrades --allow-remove-essential --allow-change-held-packages"

        cat >> /etc/profile.d/${SOFTWARE_NAME}.sh << EOF
export FLUENT_BIN_NAME=fluent
export FLUENT_CONF_DIR=/etc/${FLUENT_BIN_NAME}
export FLUENT_PLUGIN_DIR=${FLUENT_CONF_DIR}/plugin
export FLUENT_LOG_DIR=/var/log/${FLUENT_BIN_NAME}
export FLUENT_PID_DIR=/var/run/${FLUENT_BIN_NAME}
export FLUENT_CONF_FILE=${FLUENT_CONF_DIR}/${FLUENT_BIN_NAME}.conf
EOF

        export FLUENT_BIN_NAME=fluent
        export FLUENT_CONF_DIR=/etc/${FLUENT_BIN_NAME}
        export FLUENT_PLUGIN_DIR=${FLUENT_CONF_DIR}/plugin
        export FLUENT_LOG_DIR=/var/log/${FLUENT_BIN_NAME}
        export FLUENT_PID_DIR=/var/run/${FLUENT_BIN_NAME}
        export FLUENT_CONF_FILE=${FLUENT_CONF_DIR}/${FLUENT_BIN_NAME}.conf
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
    [ -d "/opt/${FLUENT_BIN_NAME}" ] || \
        git clone --quiet https://github.com/fluent/fluentd.git /opt/${FLUENT_BIN_NAME}

    cd /opt/${FLUENT_BIN_NAME}
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
    ln -sf /usr/local/bin/fluentd /usr/sbin/${FLUENT_BIN_NAME}

    # Add System User (ref deb package)
    if ! getent passwd ${FLUENT_BIN_NAME} >/dev/null; then
        adduser --group --system --no-create-home ${FLUENT_BIN_NAME}
    fi

    for FOLDER in "${FLUENT_CONF_DIR}" "${FLUENT_PLUGIN_DIR}" "${FLUENT_CONF_DIR}" "${FLUENT_LOG_DIR}" "${FLUENT_LOG_DIR}/buffer" "${FLUENT_PID_DIR}"
    do
        [ -d "${FOLDER}" ] || mkdir -p "${FOLDER}"
        chown -R ${FLUENT_BIN_NAME} "${FOLDER}"
        chmod 0755 "${FOLDER}"
    done 

    [ -d "/var/log/${FLUENT_BIN_NAME}/buffer/" ]&& \
        chown -R ${FLUENT_BIN_NAME}:${FLUENT_BIN_NAME} /var/log/${FLUENT_BIN_NAME}/buffer/
    [ -d "/tmp/${FLUENT_BIN_NAME}/" ] && \
        chown -R ${FLUENT_BIN_NAME}:${FLUENT_BIN_NAME} /tmp/${FLUENT_BIN_NAME}/
    [ -d "/etc/logrotate.d/" ] && \
        install -m 0644 -o root -g root \
            ${MYDIR}/../files/etc/${FLUENT_BIN_NAME}/logrotate.d/${FLUENT_BIN_NAME}.logrotate /etc/logrotate.d/${FLUENT_BIN_NAME}

    if [ ! -e "/etc/default/${FLUENT_BIN_NAME}" ]; then
  cat > /etc/default/${FLUENT_BIN_NAME} <<EOF
# This file is sourced by /bin/sh from /etc/init.d/${FLUENT_BIN_NAME}
# Options to pass to td-agent
TD_AGENT_OPTIONS=""

EOF
    fi

    install -m 0755 -o root -g root \
        ${MYDIR}/../files/etc/init.d/${FLUENT_BIN_NAME} /etc/init.d/${FLUENT_BIN_NAME}

    if [ -x "/etc/init.d/${FLUENT_BIN_NAME}" ]; then
        if [ ! -e "/etc/init/${FLUENT_BIN_NAME}.conf" ]; then
            update-rc.d ${FLUENT_BIN_NAME} defaults >/dev/null
        fi
        # invoke-rc.d ${FLUENT_BIN_NAME} start || exit $?
    fi

    gem install fluent-plugin-record-reformer
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

function precise::ppc64le::install_fluentd() { 
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
# Note: keeping "all::all" because probable changes with upstart/systemd
# 
#####################################################################

# This creates the file structure for template storage
function all::all::start_fluentd() {
    juju-log "Restarting Service ${FLUENT_BIN_NAME}"
    status-set maintenance "Restarting Service ${FLUENT_BIN_NAME}"
    service ${FLUENT_BIN_NAME} start || service ${FLUENT_BIN_NAME} restart
    status-set active "${FLUENT_BIN_NAME} installed and running"
}

function all::all::stop_fluentd() {
    juju-log "Stopping Service ${FLUENT_BIN_NAME}"
    status-set maintenance "Stopping Service ${FLUENT_BIN_NAME}"
    service ${FLUENT_BIN_NAME} stop
    status-set maintenance "${FLUENT_BIN_NAME} installed but not running"
}

function all::all::reload_fluentd() {
    juju-log "Reloading Service ${FLUENT_BIN_NAME}"
    status-set maintenance "Reloading Service ${FLUENT_BIN_NAME}"
    service ${FLUENT_BIN_NAME} reload || service ${FLUENT_BIN_NAME} force-reload
    status-set active "${FLUENT_BIN_NAME} installed and running"
}

#####################################################################
#
# Configuration
# 
#####################################################################

# This creates the file structure for template storage
function all::all::configure_fluentd() {
    # Emulating the structure of Apache vhosts in this context
    for FOLDER in "${FLUENT_CONF_DIR}/conf.d" "${FLUENT_CONF_DIR}/conf.d/enabled"
    do
        [ -d "${FOLDER}" ] || mkdir -p "${FOLDER}"
        chmod 0755 "${FOLDER}"
    done 

    charm::lib::get_templates "${TEMPLATE_DIR}"

    # Copying existing templates 
    ln -sf "${TEMPLATE_DIR}/${SOFTWARE_CLASS}/${SOFTWARE_NAME}" "${FLUENT_CONF_DIR}/conf.d/available"

    # cronjob for fluentd to add configuration
    install -m 0755 -o root -g root \
        ${MYDIR}/../files/usr/local/bin/fluentd-update-config.sh /usr/local/bin/fluentd-update-config.sh
    install -m 0755 -o root -g root \
        ${MYDIR}/../files/usr/local/bin/fluentd-add-output.sh /usr/local/bin/fluentd-add-output.sh

    install -m 0755 -o root -g root \
        ${MYDIR}/../files/etc/cron.d/fluentd /etc/cron.d/fluentd

    sed -i "s,FLUENT_CONF_DIR,${FLUENT_CONF_DIR},g" /etc/cron.d/fluentd

    install -m 0644 -o root -g root \
        "${MYDIR}/../files/etc/${FLUENT_BIN_NAME}/${FLUENT_BIN_NAME}.conf" "/etc/${FLUENT_BIN_NAME}/${FLUENT_BIN_NAME}.conf"

    service cron restart

    chmod -R a+r /var/log
}

#####################################################################
#
# Relating to ElasticSearch
# 
#####################################################################

@hook 'elasticsearch-relation-joined'
function initialize_connection_to_elasticsearch() {
    juju-log "Detected Elasticsearch relation. Connecting."
}

@hook 'elasticsearch-relation-changed'
function connect_to_elasticsearch() {
    # Hard coding plugin name 
    PLUGIN=elasticsearch

    # [ -z "$(relation-get cluster-name)" ] && exit 0

    juju-log $JUJU_REMOTE_UNIT modified its settings

    PLUGIN_HOST=""
    for MEMBER in $(relation-list)
    do
        ES_HOST=$(relation-get private-address ${MEMBER})
        ES_PORT=$(relation-get port ${MEMBER})
        PLUGIN_HOST+="${ES_HOST}:${ES_PORT},"
    done
    PLUGIN_HOST="$(echo ${PLUGIN_HOST} | head -c -2)"

    # juju-log /usr/local/bin/fluentd-add-output.sh -p "${PLUGIN}" -h "${PLUGIN_HOST}" && \
    /usr/local/bin/fluentd-add-output.sh \
        -p "${PLUGIN}" \
        -h "${PLUGIN_HOST}" \
        -c "${FLUENT_CONF_DIR}"
}

@hook 'elasticsearch-relation-departed'
function disconnect_from_elasticsearch() {
    juju-log "Detected Elasticsearch relation destruction. Disconnecting."
    connect_to_elasticsearch
}

#####################################################################
#
# Relating to HDFS
# 
#####################################################################

@hook 'namenode-relation-joined'
function initialize_connection_to_hdfs() {
    juju-log "Detected DFS relation. Connecting."
}

@hook 'namenode-relation-changed'
function connect_to_hdfs() {
    # Hard coding plugin name 
    PLUGIN=hdfs

    # [ -z "$(relation-get cluster-name)" ] && exit 0

    juju-log $JUJU_REMOTE_UNIT modified its settings

    PLUGIN_HOST=""
    for MEMBER in $(relation-list)
    do
        NAMENODE_HOST=$(relation-get private-address ${MEMBER})
        NAMENODE_PORT=$(relation-get webhdfs-port ${MEMBER})
        PLUGIN_HOST+="${NAMENODE_HOST}:${NAMENODE_PORT},"
    done
    PLUGIN_HOST="$(echo ${PLUGIN_HOST} | head -c -2)"

    # juju-log /usr/local/bin/fluentd-add-output.sh -p "${PLUGIN}" -h "${PLUGIN_HOST}" && \
    /usr/local/bin/fluentd-add-output.sh \
        -p "${PLUGIN}" \
        -h "${PLUGIN_HOST}" \
        -c "${FLUENT_CONF_DIR}"
}

@hook 'namenode-relation-departed'
function disconnect_from_hdfs() {
    juju-log "Detected DFS relation destruction. Disconnecting."
    connect_to_hdfs
}

#####################################################################
#
# Relating to InfluxDB
# Note: we actually don't manage username:password in this example
# 
#####################################################################

@hook 'influxdb-relation-joined'
function initialize_connection_to_influxdb() {
    juju-log "Detected influxdb relation. Connecting."
}

@hook 'influxdb-relation-changed'
function connect_to_influxdb() {
    # Hard coding plugin name 
    PLUGIN=influxdb

    # [ -z "$(relation-get cluster-name)" ] && exit 0

    juju-log $JUJU_REMOTE_UNIT modified its settings

    PLUGIN_HOST=""
    for MEMBER in $(relation-list)
    do
        INFLUXDB_HOST=$(relation-get hostname ${MEMBER})
        INFLUXDB_PORT=$(relation-get port ${MEMBER})
        INFLUXDB_USERNAME=$(relation-get username ${MEMBER})
        INFLUXDB_PASSWORD=$(relation-get password ${MEMBER})
        PLUGIN_HOST+="${INFLUXDB_HOST}:${INFLUXDB_PORT},"
    done
    PLUGIN_HOST="$(echo ${PLUGIN_HOST} | head -c -2)"

    # juju-log /usr/local/bin/fluentd-add-output.sh -p "${PLUGIN}" -h "${PLUGIN_HOST}" && \
    /usr/local/bin/fluentd-add-output.sh \
        -p "${PLUGIN}" \
        -h "${PLUGIN_HOST}" \
        -c "${FLUENT_CONF_DIR}"
}

@hook 'influxdb-relation-departed'
function disconnect_from_influxdb() {
    juju-log "Detected influxdb relation destruction. Disconnecting."
    connect_to_influxdb
}

#####################################################################
#
# Juju Lifecycle 
# 
#####################################################################

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

