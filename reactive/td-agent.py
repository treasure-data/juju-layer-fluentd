from charms.reactive import when_not, set_state
from charmhelpers import fetch
import subprocess


@when_not('td-agent.installed')
def install_td_agent():

    # Add apt source for fluentd, using the source/key in config.yaml
    fetch.configure_sources()
    fetch.apt_update()

    # Install ruby and td-agent
    packages = ['ruby', 'td-agent']
    fetch.apt_install(fetch.filter_installed_packages(packages))

    # Configure td-agent
    set_state('td-agent.installed')
