#! /usr/bin/env ruby

# -----------------------
# Author: Andreas Paul (xorpaul) <xorpaul@gmail.com>
# Date: 2014-02-05 17:06
# Version: 0.1
# -----------------------
#
# http://docs.puppetlabs.com/puppetdb/latest/api/query/v3/metrics.html

require 'rubygems'
require 'optparse'
require 'open-uri'
require 'uri'
require 'json'

$debug = false
$checkmk = false
$host = ''
$timeout = 5
$port = 8080
$queuewarn = 500
$queuecrit = 2000
$cmd_p_secwarn = 0.5
$cmd_p_seccrit = 0.2

opt = OptionParser.new
opt.on("--debug", "-d", "print debug information, defaults to #{$debug}") do |f|
    $debug = true
end
opt.on("--checkmk", "append HTML </br> to each line in the long output to display line breaks check_mk GUI, defaults to #{$checkmk}") do |c|
    $checkmk = true
end
opt.on("--host [PUPPETDBSERVER]", "-H", "Your PuppetDB hostname, MANDATORY parameter") do |host_p|
    $host = host_p
end
opt.on("--port [PORT]", "-p", Integer, "Your PuppetDB port, defaults to #{$port}") do |port_p|
    $port = port_p
end
opt.on("--timeout [SECONDS]", "-t", Integer, "Timeout for each HTTP GET request, defaults to #{$timeout} seconds") do |timeout_p|
    $timeout = timeout_p
end
opt.on("--queuewarn [WARNTHRESHOLD]", Integer, "WARNING threshold for PuppetDB queue size, defaults to #{$queuewarn}") do |qw_p|
    $queuewarn = qw_p
end
opt.on("--queuecrit [CRITTHRESHOLD]", Integer, "CRITICAL threshold for PuppetDB queue size, defaults to #{$queuecrit}") do |qc_p|
    $queuecrit = qc_p
end
opt.on("--cmd_p_secwarn [WARNTHRESHOLD]", Float, "WARNING threshold for Commands processed per second, defaults to #{$cmd_p_secwarn} cmds/s") do |cw_p|
    $cmd_p_secwarn = cw_p
end
opt.on("--cmd_p_seccrit [CRITTHRESHOLD]", Float, "CRITICAL threshold for Commands processed per second, defaults to #{$cmd_p_seccrit} cmds/s") do |cc_p|
    $cmd_p_seccrit = cc_p
end
opt.parse!

if $host == '' || $host == nil
    puts 'ERROR: Please specify your PuppetDB server with -H <PUPPETDBSERVER>'
    puts "Example: #{__FILE__} -H puppetdb.domain.tld"
    puts opt
    exit 3
end

def doRequest(url)
  out = {'returncode' => 0}
  puts "sending GET to #{url}" if $debug
  begin
    uri = URI.parse(url)
    response = uri.read(:read_timeout => $timeout)
    puts "Response: #{response}" if $debug
    out['data'] = JSON.load(response)
  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Errno::ECONNREFUSED,
    Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
    out['text'] = "WARNING: Error '#{e}' while sending request to #{url}"
    out['returncode'] = 1
  end
  puts "Parsed: #{out['data']}" if $debug
  return out
end

def commandProcessingMetrics(host, port, warn, crit)
  result = {'perfdata' => ''}
  url = "http://#{host}:#{port}/v3/metrics/mbean/com.puppetlabs.puppetdb.command:type=global,name=processing-time"
  data = doRequest(url)
  if data['returncode'] == 0
    oneMinuteRate = data['data']['OneMinuteRate'].round(3)
    fiveMinuteRate = data['data']['FiveMinuteRate'].round(3)
    fifteenMinuteRate = data['data']['FifteenMinuteRate'].round(3)
    fiftyPercentile = data['data']['50thPercentile'].round(3)
    if fiveMinuteRate <= crit
      text = 'CRITICAL: '
      rc = 2
    elsif fiveMinuteRate <= warn
      text = 'WARNING: '
      rc = 1
    else
      text = ''
      rc = 0
    end
    result['text'] = "#{text}#{fiveMinuteRate} cmds/s #{fiftyPercentile} ms/cmd"
    result['returncode'] = rc
    result['perfdata'] = "cmd_s_1m=#{oneMinuteRate} cmd_s_5m=#{fiveMinuteRate};#{warn};#{crit} cmd_s_15m=#{fifteenMinuteRate} ms_cmd50=#{fiftyPercentile}ms"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def databaseMetrics(host, port)
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{host}:#{port}/v3/metrics/mbean/com.jolbox.bonecp:type=BoneCP"
  data = doRequest(url)
  if data['returncode'] == 0
    totalCreatedConnections = data['data']['TotalCreatedConnections']
    totalLeased = data['data']['TotalLeased']
    statementExecuteTimeAvg = data['data']['StatementExecuteTimeAvg'].round(3)
    statementPrepareTimeAvg = data['data']['StatementPrepareTimeAvg'].round(3)
    result['text'] = "used DB connections: #{totalLeased}"
    result['perfdata'] = "max_connections=#{totalCreatedConnections} used_connections=#{totalLeased} db_exec_avg_time=#{statementExecuteTimeAvg}ms db_prepare_avg_time=#{statementPrepareTimeAvg}ms"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def JvmMetrics(host, port)
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{host}:#{port}/v3/metrics/mbean/java.lang:type=Memory"
  data = doRequest(url)
  if data['returncode'] == 0
    heapMemoryUsage_used = data['data']['HeapMemoryUsage']['used']
    heapMemoryUsage_max = data['data']['HeapMemoryUsage']['max']
    result['text'] = "JVM #{heapMemoryUsage_used / 1024 / 1024}MB"
    result['perfdata'] = "jvm_used=#{heapMemoryUsage_used}B jvm_max=#{heapMemoryUsage_max}B"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def commandProcessedMetrics(host, port)
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{host}:#{port}/v3/metrics/mbean/com.puppetlabs.puppetdb.command:type=global,name=processed"
  data = doRequest(url)
  if data['returncode'] == 0
    processed = data['data']['Count']
    result['text'] = "processed: #{processed}"
    result['perfdata'] = "processed=#{processed}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def queueMetrics(host, port, warn, crit)
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{host}:#{port}/v3/metrics/mbean/org.apache.activemq:BrokerName=localhost,Type=Queue,Destination=com.puppetlabs.puppetdb.commands"
  data = doRequest(url)
  if data['returncode'] == 0
    queueSize = data['data']['QueueSize']
    threads = data['data']['ConsumerCount']
    if queueSize >= crit
      text = 'CRITICAL: '
      rc = 2
    elsif queueSize >= warn
      text = 'WARNING: '
      rc = 1
    else
      text = ''
      rc = 0
    end
    result['text'] = "#{text}Queue size: #{queueSize} threads: #{threads}"
    result['returncode'] = rc
    result['perfdata'] = "queue_size=#{queueSize};#{warn};#{crit} threads=#{threads}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def catalogDuplicatesMetrics(host, port)
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{host}:#{port}/v3/metrics/mbean/com.puppetlabs.puppetdb.scf.storage:type=default,name=duplicate-pct"
  data = doRequest(url)
  if data['returncode'] == 0
    c_dup_perc = (data['data']['Value'] * 100)
    result['text'] = "Catalog duplication: #{c_dup_perc.round(1)}%"
    result['perfdata'] = "catalog_duplication=#{c_dup_perc.round(3)}%"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def populationNodesMetrics(host, port)
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{host}:#{port}/v3/metrics/mbean/com.puppetlabs.puppetdb.query.population:type=default,name=num-nodes"
  data = doRequest(url)
  if data['returncode'] == 0
    num_nodes = data['data']['Value']
    result['text'] = "nodes: #{num_nodes}"
    result['perfdata'] = "num_nodes=#{num_nodes}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def populationResourcesMetrics(host, port)
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{host}:#{port}/v3/metrics/mbean/com.puppetlabs.puppetdb.query.population:type=default,name=num-resources"
  data = doRequest(url)
  if data['returncode'] == 0
    num_nodes = data['data']['Value']
    result['text'] = "resources: #{num_nodes}"
    result['perfdata'] = "resources=#{num_nodes}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

results = []
if $debug == false
  # threading
  threads = []
  threads << Thread.new{ results << commandProcessingMetrics($host, $port, $cmd_p_secwarn, $cmd_p_seccrit) }
  threads << Thread.new{ results << commandProcessedMetrics($host, $port) }
  threads << Thread.new{ results << databaseMetrics($host, $port) }
  threads << Thread.new{ results << JvmMetrics($host, $port) }
  threads << Thread.new{ results << queueMetrics($host, $port, $queuewarn, $queuecrit) }
  threads << Thread.new{ results << catalogDuplicatesMetrics($host, $port) }
  threads << Thread.new{ results << populationNodesMetrics($host, $port) }
  # disabled for now, because it's rather wasteful
  #threads << Thread.new{ results << populationResourcesMetrics($host, $port) }

  threads.each do |t|
    t.join
  end
else
  results << commandProcessingMetrics($host, $port, $cmd_p_secwarn, $cmd_p_seccrit)
  results << commandProcessedMetrics($host, $port)
  results << databaseMetrics($host, $port)
  results << JvmMetrics($host, $port)
  results << queueMetrics($host, $port, $queuewarn, $queuecrit)
  results << catalogDuplicatesMetrics($host, $port)
  results << populationNodesMetrics($host, $port)
  #results << populationResourcesMetrics($host, $port)
end

puts results if $debug

# Aggregate check results
output = {}
output['returncode'] = 0
output['text'] = ''
output['text_if_ok'] = ''
output['multiline'] = ''
output['perfdata'] = ''
results.each do |result|
  output['perfdata'] += "#{result['perfdata']} " if result['perfdata'] != ''
  if result['returncode'] >= 1
    output['text'] += "#{result['text']} "
    case result['returncode']
    when 3
      output['returncode'] = 3 if result['returncode'] > output['returncode']
    when 2
      output['returncode'] = 2 if result['returncode'] > output['returncode']
    when 1
      output['returncode'] = 1 if result['returncode'] > output['returncode']
    end
  else
    output['text_if_ok'] += "#{result['text']} "
    br = ''
    br = '</br>' if $checkmk
    output['multiline'] += "#{result['text']}#{br}\n"
  end
end

if output['text'] == ''
  output['text'] = output['text_if_ok']
end

puts "#{output['text']}|#{output['perfdata']}\n#{output['multiline'].chomp()}"

exit output['returncode']
