# Overview

td-agent (Fluentd) is an open source data collection tool that allows you to
implement unified logging layers in your environment.

It support more than 300 extensions to manage different input sources such as
Docker, Syslog, Nginx, Apache and several outputs such as Elasticsearch, HDFS,
MongoDB, Amazon S3, Kafka within many.

The Juju charm implementation automates a lot of the ground work to implement Fluent. 

* At installation, installation will 
	* Add a cron job scanning for other local charms. 
	* Copy a repo of known input configuration files (open to contributions)
* When a local charm matches a known input, it is automatically added to the list of enabled inputs

There are currently 

* About 10 input plugins automagically managed:
	* all Ceph workloads
	* all OpenStack components
	* Ubuntu "default" images
* 3 output plugins supported by the charm
	* ElasticSearch
	* InfluxDB
	* HDFS

# Usage
## Deploying the agent

```
$ juju deploy fluentd
```

## Relating the agent to another charm

```
$ juju add-relation fluentd:juju-info ubuntu:juju-info
```

## Adding a relation to a backend
### ElasticSearch

```
$ juju add-relation fluentd elasticsearch
```

Note that if you have multiple ES instances, this will load balance the flow of log messages.

### InfluxDB

```
$ juju add-relation fluentd influxdb
```

### Hadoop

```
$ juju add-relation fluentd namenode
```

Currently relations to a secondary namenode is not managed, nor is the migration between the 2. 

# Contributing
## Adding input plugins

If there are more charms you'd like to create input for, you can PR new configuration snippets to the [Repository of Charm plugins](https://github.com/SaMnCo/ops-templates)

Any input plugin is made of 

* an input_${charm-name}.conf file with the configuration of the input. <charm-name> must match the name of the target charm in metadata.yaml

The format of the processing chain is described in the documentation of the repo. It is possible to create chained and filters, but the final filter has to follow a convention to make it generic enough.

As input plugins are supposedly automatic, the files/usr/local/bin/fluentd-update-config.sh script must be modified to handle the new possibility. 

## Adding output plugins

An output plugin is made of: 

* an install.sh script that will be run prior to the installation of the plugin (usually installing just the gem that is needed)
* an output_${charm-name}.conf file with the configuration of the output. <charm-name> must match the name of the target charm in metadata.yaml

Also, as output plugins are managed by relations, you must also modify this charm to manage the new relation. You'll have to edit

* metadata.yaml to add the new charm to the list of requires
* reactive/fluentd.sh to add the code managed by the relation
* [layer.yaml] : if you are using a layered interface, you'll need to include it for the build time

The matching rules must follow a pre-defined format documented in the repo, to make sure that all necessary logs are collected. 

# Contact Information

This charm is provided by [Treasure Data](https://www.treasuredata.com), if you need further assistance contact us through our [support channels](https://docs.treasuredata.com/articles/support-channels).

## Upstream Project Name

- [Project Website](http://fluentd.org)
- [Mailing List](https://groups.google.com/forum/?fromgroups#!forum/fluentd)


