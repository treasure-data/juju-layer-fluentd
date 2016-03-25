from charms.reactive import when, when_not, set_state, when_file_changed
from charmhelpers import fetch
from charmhelpers.core.templating import render
from charmhelpers.core.hookenv import status_set, log
from charmhelpers.core.host import service_restart

import subprocess

def td_log(comp, msg):
    log('[td-agent] [%s] %s' % (comp, msg))

@when_not('td-agent.installed')
def install_td_agent():

    # Add apt source for fluentd, using the source/key in config.yaml
    fetch.configure_sources()
    fetch.apt_update()

    # Install ruby and td-agent
    packages = ['ruby', 'td-agent']
    fetch.apt_install(fetch.filter_installed_packages(packages))

    # Override default configuration
    render(source='td-agent.conf',
           target='/etc/td-agent/td-agent.conf',
           owner='root',
           perms=0o644,
           context={})

    # Install process is done
    set_state('td-agent.installed')
    status_set('maintenance', 'Starting td-agent...')


def restart_td_agent():
     status_set('maintenance', 'Re-starting td-agent...')
     service_restart('td-agent')

@when('out_mongodb.database.available')
def out_mongodb_set(mongo):
    conn = mongo.connection_string()
    if conn is None:
        td_log('missing connection string')
        return

    host, port = conn.split(':')
    td_log('new database host=%s port%s' % (host, port))
    status_set('maintenance', 'new database host=%s port%s' % (host, port))

@when_file_changed('/etc/td-agent/td-agent.conf')
def restart_service():
    restart_td_agent()
