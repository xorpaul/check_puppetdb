check_puppetdb
==============

PuppetDB monitoring script for Nagios/Icinga/Shinken

Using PuppetDB API (http://docs.puppetlabs.com/puppetdb/latest/api/query/v3/metrics.html) to query certain metrics for monitoring and statistic purposes.

DEPENDENCIES:
--------
* ruby 1.9.3
* JSON gem


USAGE:
--------


```
Usage: check_puppetdb [options]
    -d, --debug                      print debug information, defaults to false
        --checkmk                    append HTML </br> to each line in the long output to display line breaks check_mk GUI, defaults to false
    -H, --host [PUPPETDBSERVER]      Your PuppetDB hostname, MANDATORY parameter
    -p, --port [PORT]                Your PuppetDB port, defaults to 8080
    -s, --sslport [SSLPORT]          Your PuppetDB SSL port, defaults to 8081
    -t, --timeout [SECONDS]          Timeout for each HTTP GET request, defaults to 5 seconds
        --queuewarn [WARNTHRESHOLD]  WARNING threshold for PuppetDB queue size, defaults to 500
        --queuecrit [CRITTHRESHOLD]  CRITICAL threshold for PuppetDB queue size, defaults to 2000
        --cmd_p_secwarn [WARNTHRESHOLD]
                                     WARNING threshold for Commands processed per second, defaults to 0.5 cmds/s
        --cmd_p_seccrit [CRITTHRESHOLD]
                                     CRITICAL threshold for Commands processed per second, defaults to 0.2 cmds/s
```

**Example**

```
$ ruby check_puppetdb.rb -H puppetdb
CRITICAL: Queue size: 2633 threads: 2 WARNING: 0.317 cmds/s 311.254 ms/cmd |processed=654533 jvm_used=8398051784B jvm_max=13788119040B max_connections=46 used_connections=3 db_exec_avg_time=6.906ms db_prepare_avg_time=64.813ms num_nodes=8522 queue_size=2633;500;2000 threads=2 catalog_duplication=72.592% cmd_s_1m=3.497 cmd_s_5m=0.317;0.5;0.2 cmd_s_15m=2.139 ms_cmd50=311.254ms 
processed: 654533
JVM 8009MB
used DB connections: 3
nodes: 8522
Catalog duplication: 72.6%
2.956 cmds/s 358.246 ms/cmd
$ echo $?
2
$ ruby check_puppetdb.rb -H puppetdb
Catalog duplication: 75.5% JVM 6116MB 2.391 cmds/s 342.131 ms/cmd used DB connections: 0 Queue size: 0 threads: 2 processed: 2036061 nodes: 8643 |catalog_duplication=75.46% jvm_used=6413597160B jvm_max=13751877632B cmd_s_1m=2.343 cmd_s_5m=2.391;0.5;0.2 cmd_s_15m=2.421 ms_cmd50=342.131ms max_connections=44 used_connections=0 db_exec_avg_time=7.495ms db_prepare_avg_time=64.371ms queue_size=0;500;2000 threads=2 processed=2036061 num_nodes=8643 
Catalog duplication: 75.5%
JVM 6116MB
2.391 cmds/s 342.131 ms/cmd
used DB connections: 0
Queue size: 0 threads: 2
processed: 2036061
nodes: 8643
$ echo $?
0
```

![graphite](https://github.com/xorpaul/check_puppetdb/raw/master/example-images/graphite.png)
