check_puppetdb
==============

PuppetDB monitoring script for Nagios/Icinga/Shinken

Support for PuppetDB API:
* PuppetDB version 4.3 (https://docs.puppet.com/puppetdb/4.3/api/metrics/v1/mbeans.html)
* PuppetDB version 4.0 (https://docs.puppet.com/puppetdb/4.0/api/metrics/v1/mbeans.html)
* PuppetDB version 3 (https://docs.puppet.com/puppetdb/3.0/api/metrics/v1/mbeans.html)
* PuppetDB version 1.6 (API version 3) (https://docs.puppet.com/puppetdb/1.6/api/query/v3/metrics.html)

DEPENDENCIES:
--------
* ruby 1.9.3
* JSON gem


USAGE:
--------


```
Usage: check_puppetdb [options]
    -d, --debug                      print debug information, defaults to false
        --checkmk                    append HTML </br> to each line in the long output to display line breaks in the check_mk GUI, defaults to false
    -H, --host [PUPPETDBSERVER]      Your PuppetDB hostname, MANDATORY parameter
    -p, --port [PORT]                Your PuppetDB port, defaults to 8080
    -s, --sslport [SSLPORT]          Your PuppetDB SSL port, defaults to 8081
    -t, --timeout [SECONDS]          Timeout for each HTTP GET request, defaults to 5 seconds
        --queuewarn [WARNTHRESHOLD]  WARNING threshold for PuppetDB queue size, defaults to 500
        --queuecrit [CRITTHRESHOLD]  CRITICAL threshold for PuppetDB queue size, defaults to 2000
        --cmd_p_secwarn [WARNTHRESHOLD]
                                     WARNING threshold for Commands processed per second, defaults to -1 cmds/s
        --cmd_p_seccrit [CRITTHRESHOLD]
                                     CRITICAL threshold for Commands processed per second, defaults to -1 cmds/s
```

![checkmk](https://github.com/xorpaul/check_puppetdb/raw/master/example-images/checkmk.png)

**Example**

PuppetDB 4.3
```
$ ruby check_puppetdb.rb -H puppetdb43
Catalog duplication: 0.0% 0.0 cmds/s 2131.14 ms/cmd JVM 80MB used of 171MB (47.0%) nodes: 3 Read pool - active DB connections: 1 max DB connections: 25 Write pool - active DB connections: 0 max DB connections: 25 processed: 2 Queue size: 0 Resource duplication: 26.1% resources: 902 retried: 0 thread count: 40 peak thread count: 51 daemon thread count: 19 |catalog_duplication=0.0% cmd_s_1m=0.0 cmd_s_5m=0.0;-1;-1 cmd_s_15m=0.0 ms_cmd50=2131.14ms jvm_used=84275720B jvm_max=179306496B jvm_used_perc=47.00092962610791% num_nodes=3 pool_read_used_connections=1 pool_read_max_connections=25 pool_write_used_connections=0 pool_write_max_connections=25 processed=2 queue_size=0;500;2000 resource_duplication=26.053% resources=902 retried=0 thread_count=40 peak_thread_count=51 daemon_thread_count=19 
Catalog duplication: 0.0%
0.0 cmds/s 2131.14 ms/cmd
JVM 80MB used of 171MB (47.0%)
nodes: 3
Read pool - active DB connections: 1 max DB connections: 25
Write pool - active DB connections: 0 max DB connections: 25
processed: 2
Queue size: 0
Resource duplication: 26.1%
resources: 902
retried: 0
thread count: 40 peak thread count: 51 daemon thread count: 19
$ echo $?
0
```
PuppetDB 4.0
```
$ ruby check_puppetdb.rb -H puppetdb4
retried: 0 0.0 cmds/s 6.227 ms/cmd resources: 0 nodes: 1 Queue size: 0 threads: 2 processed: 10 Resource duplication: 0.0% Catalog duplication: 0.0% JVM 126MB used of 171MB (74.18%) Write pool - active DB connections: 0 max DB connections: 25 Read pool - active DB connections: 0 max DB connections: 25 |retried=0 cmd_s_1m=0.0 cmd_s_5m=0.0;-1;-1 cmd_s_15m=0.0 ms_cmd50=6.227ms resources=0 num_nodes=1 queue_size=0;500;2000 threads=2 processed=10 resource_duplication=0.0% catalog_duplication=0.0% jvm_used=133011608B jvm_max=179306496B jvm_used_perc=74.18114288508544% pool_write_used_connections=0 pool_write_max_connections=25 pool_read_used_connections=0 pool_read_max_connections=25 
retried: 0
0.0 cmds/s 6.227 ms/cmd
resources: 0
nodes: 1
Queue size: 0 threads: 2
processed: 10
Resource duplication: 0.0%
Catalog duplication: 0.0%
JVM 126MB used of 171MB (74.18%)
Write pool - active DB connections: 0 max DB connections: 25
Read pool - active DB connections: 0 max DB connections: 25
$ echo $?
0
```
PuppetDB 3.x
```
$ ruby check_puppetdb.rb -H puppetdb3
retried: 1720 processed: 3177935 used DB connections: 0 JVM 1091MB used of 8533MB (12.79%) resources: 346102 nodes: 1447 Queue size: 0 threads: 2 0.852 cmds/s 209.022 ms/cmd Catalog duplication: 63.8% Resource duplication: 88.2% |retried=1720 processed=3177935 max_connections=0 used_connections=0 db_exec_avg_time=1.774ms db_prepare_avg_time=1.681ms jvm_used=1144591320B jvm_max=8948023296B jvm_used_perc=12.791554985240843% resources=346102 num_nodes=1447 queue_size=0;500;2000 threads=2 cmd_s_1m=0.965 cmd_s_5m=0.852;-1;-1 cmd_s_15m=0.849 ms_cmd50=209.022ms catalog_duplication=63.787% resource_duplication=88.173% 
retried: 1720
processed: 3177935
used DB connections: 0
JVM 1091MB used of 8533MB (12.79%)
resources: 346102
nodes: 1447
Queue size: 0 threads: 2
0.852 cmds/s 209.022 ms/cmd
Catalog duplication: 63.8%
Resource duplication: 88.2%
$ echo $?
0
$ ruby check_puppetdb.rb -H puppetdb3 --cmd_p_secwarn 0.9
WARNING: 0.868 cmds/s 209.714 ms/cmd |processed=3177999 cmd_s_1m=0.936 cmd_s_5m=0.868;0.9;-1 cmd_s_15m=0.855 ms_cmd50=209.714ms retried=1720 queue_size=0;500;2000 threads=2 catalog_duplication=63.787% max_connections=0 used_connections=0 db_exec_avg_time=1.774ms db_prepare_avg_time=1.681ms num_nodes=1447 resource_duplication=88.174% resources=346102 jvm_used=1956349752B jvm_max=8948023296B jvm_used_perc=21.86348523337595% 
processed: 3177999
retried: 1720
Queue size: 0 threads: 2
Catalog duplication: 63.8%
used DB connections: 0
nodes: 1447
Resource duplication: 88.2%
resources: 346102
JVM 1865MB used of 8533MB (21.86%)
$ echo $?
1
```
PuppetDB 1.6
```
$ ruby check_puppetdb.rb -H puppetdb
CRITICAL: Queue size: 2633 threads: 2 WARNING: 0.317 cmds/s 311.254 ms/cmd retried: 321 |processed=654533 jvm_used=8398051784B jvm_max=13788119040B max_connections=46 used_connections=3 db_exec_avg_time=6.906ms db_prepare_avg_time=64.813ms num_nodes=8522 queue_size=2633;500;2000 threads=2 catalog_duplication=72.592% cmd_s_1m=3.497 cmd_s_5m=0.317;0.5;0.2 cmd_s_15m=2.139 ms_cmd50=311.254ms retried=321
processed: 654533
JVM 8009MB
used DB connections: 3
nodes: 8522
Catalog duplication: 72.6%
2.956 cmds/s 358.246 ms/cmd
$ echo $?
2
$ ruby check_puppetdb.rb -H puppetdb
Catalog duplication: 75.5% JVM 6116MB 2.391 cmds/s 342.131 ms/cmd used DB connections: 0 Queue size: 0 threads: 2 processed: 2036061 nodes: 8643 retried: 321 |catalog_duplication=75.46% jvm_used=6413597160B jvm_max=13751877632B cmd_s_1m=2.343 cmd_s_5m=2.391;0.5;0.2 cmd_s_15m=2.421 ms_cmd50=342.131ms max_connections=44 used_connections=0 db_exec_avg_time=7.495ms db_prepare_avg_time=64.371ms queue_size=0;500;2000 threads=2 processed=2036061 num_nodes=8643 retried=321
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
