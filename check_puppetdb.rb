#! /usr/bin/env ruby

# -----------------------
# Author: Andreas Paul (xorpaul) <xorpaul@gmail.com>
# Date: 2014-02-05 17:06
# Version: 0.1
# -----------------------
#
# https://docs.puppetlabs.com/puppetdb/3.1/api/metrics/v1/mbeans.html

require 'rubygems'
require 'optparse'
require 'open-uri'
require 'uri'
require 'json'
require 'socket'
require 'timeout'

$debug = false
$checkmk = false
$host = ''
$timeout = 5
$port = 8080
$sslport = $port + 1
$queuewarn = 500
$queuecrit = 2000
$cmd_p_secwarn = -1
$cmd_p_seccrit = -1
$api_version = 4

opt = OptionParser.new
opt.on("--debug", "-d", "print debug information, defaults to #{$debug}") do |f|
    $debug = true
end
opt.on("--checkmk", "append HTML </br> to each line in the long output to display line breaks in the check_mk GUI, defaults to #{$checkmk}") do |c|
    $checkmk = true
end
opt.on("--host [PUPPETDBSERVER]", "-H", "Your PuppetDB hostname, MANDATORY parameter") do |host_p|
    $host = host_p
end
opt.on("--port [PORT]", "-p", Integer, "Your PuppetDB port, defaults to #{$port}") do |port_p|
    $port = port_p
end
opt.on("--sslport [SSLPORT]", "-s", Integer, "Your PuppetDB SSL port, defaults to #{$port + 1}") do |sslport_p|
    $sslport = sslport_p
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

if ENV.key?('VIMRUNTIME')
    $debug = true
    $host = '10.77.202.37'
end


if $host == '' || $host == nil
    puts 'ERROR: Please specify your PuppetDB server with -H <PUPPETDBSERVER>'
    puts "Example: #{__FILE__} -H puppetdb.domain.tld"
    puts opt
    exit 3
end

# http://stackoverflow.com/a/517638/682847
def is_port_open?(ip, port)
  begin
    Timeout::timeout($timeout) do
      begin
        s = TCPSocket.new(ip, port)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        return false
      end
    end
  rescue Timeout::Error
  end

  return false
end

# http://grosser.it/2008/10/25/numbers-for-humans-humanize-for-numeric/
class Numeric
  def humanize(rounding=2,delimiter=',',separator='.')
    value = respond_to?(:round_with_precision) ? round(rounding) : self
    #see number with delimeter
    parts = value.to_s.split('.')
    parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
    parts.join separator
  end
end

def doRequest(url)
  out = {'returncode' => 0}
  puts "sending GET to #{url}" if $debug
  begin
    uri = URI.parse(url)
    response = uri.read(:read_timeout => $timeout)
    puts "Response: #{response}" if $debug
    out['data'] = JSON.load(response)
  rescue OpenURI::HTTPError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Errno::ECONNREFUSED,
    Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
    out['text'] = "WARNING: Error '#{e}' while sending request to #{url}"
    out['returncode'] = 1
  end
  puts "Parsed: #{out['data']}" if $debug
  return out
end

def checkApiVersion()
  v43url = "http://#{$host}:#{$port}/pdb/meta/v1/version"
  v1url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.command:type=global,name=processing-time"
  data = doRequest(v43url)
  return data['data']['version'][0].to_i if data['returncode'] == 0
  data = doRequest(v1url)
  return 1 if data['returncode'] == 0
end

def commandProcessingMetrics(warn, crit)
  result = {'perfdata' => ''}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.mq:name=global.processing-time"
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.command:type=global,name=processing-time"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.command:type=global,name=processing-time"
  end
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

def databaseMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/com.jolbox.bonecp:type=BoneCP"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.jolbox.bonecp:type=BoneCP"
  end
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

def databaseMetricsHikari(pool='Write')
  result = {'perfdata' => '', 'returncode' => 0}
  url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.database:name=PDB#{pool}Pool.pool.ActiveConnections"
  data = doRequest(url)
  if data['returncode'] == 0
    totalActiveConnections = data['data']['Value']
    result['text'] = "#{pool} pool - active DB connections: #{totalActiveConnections}"
    result['perfdata'] = "pool_#{pool.downcase}_used_connections=#{totalActiveConnections}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end

  url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.database:name=PDB#{pool}Pool.pool.TotalConnections"
  data = doRequest(url)
  if data['returncode'] == 0
    totalCreatedConnections = data['data']['Value']
    result['text'] += " max DB connections: #{totalCreatedConnections}"
    result['perfdata'] += " pool_#{pool.downcase}_max_connections=#{totalCreatedConnections}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def databaseMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.mq:name=global.processing-time"
    return {'perfdata' => '', 'returncode' => 0, 'text' => 'database metrics and APIv4 not supported yet'}
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/com.jolbox.bonecp:type=BoneCP"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.jolbox.bonecp:type=BoneCP"
  end
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

def JvmMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4,3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/java.lang:type=Memory"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/java.lang:type=Memory"
  end
  data = doRequest(url)
  if data['returncode'] == 0
    heapMemoryUsage_used = data['data']['HeapMemoryUsage']['used']
    heapMemoryUsage_max = data['data']['HeapMemoryUsage']['max']
    heapMemoryUsage_perc = ( heapMemoryUsage_used / heapMemoryUsage_max.to_f ) * 100
    result['text'] = "JVM #{heapMemoryUsage_used / 1024 / 1024}MB used of #{heapMemoryUsage_max / 1024 / 1024}MB (#{heapMemoryUsage_perc.round(2)}%)"
    result['perfdata'] = "jvm_used=#{heapMemoryUsage_used}B jvm_max=#{heapMemoryUsage_max}B jvm_used_perc=#{heapMemoryUsage_perc}%"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def commandProcessedMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.mq:name=global.processed"
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.command:type=global,name=processed"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.command:type=global,name=processed"
  end
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

def commandRetriedMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.mq:name=global.retried"
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.command:type=global,name=retried"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.command:type=global,name=retried"
  end
  data = doRequest(url)
  if data['returncode'] == 0
    retried = data['data']['Count']
    result['text'] = "retried: #{retried}"
    result['perfdata'] = "retried=#{retried}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def queueMetrics(warn, crit)
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4,3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/org.apache.activemq:type=Broker,brokerName=localhost,destinationType=Queue,destinationName=puppetlabs.puppetdb.commands"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/org.apache.activemq:BrokerName=localhost,Type=Queue,Destination=com.puppetlabs.puppetdb.commands"
  end
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
    result['text'] = "#{text}Queue size: #{queueSize.humanize} threads: #{threads}"
    result['returncode'] = rc
    result['perfdata'] = "queue_size=#{queueSize};#{warn};#{crit} threads=#{threads}"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def catalogDuplicatesMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.storage:name=duplicate-pct"
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.scf.storage:type=default,name=duplicate-pct"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.scf.storage:type=default,name=duplicate-pct"
  end
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

def resourceDuplicatesMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.population:name=pct-resource-dupes"
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.query.population:type=default,name=pct-resource-dupes"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.query.population:type=default,name=pct-resource-dupes"
  end
  data = doRequest(url)
  if data['returncode'] == 0
    c_dup_perc = (data['data']['Value'] * 100)
    result['text'] = "Resource duplication: #{c_dup_perc.round(1)}%"
    result['perfdata'] = "resource_duplication=#{c_dup_perc.round(3)}%"
  else
    result['text'] = data['text']
    result['returncode'] = data['returncode']
  end
  return result
end

def populationNodesMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.population:name=num-nodes"
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.query.population:type=default,name=num-nodes"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.query.population:type=default,name=num-nodes"
  end
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

def populationResourcesMetrics()
  result = {'perfdata' => '', 'returncode' => 0}
  case $api_version
  when 4
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.population:name=num-resources"
  when 3
    url = "http://#{$host}:#{$port}/metrics/v1/mbeans/puppetlabs.puppetdb.query.population:type=default,name=num-resources"
  when 1
    url = "http://#{$host}:#{$port}/v3/metrics/mbean/com.puppetlabs.puppetdb.query.population:type=default,name=num-resources"
  end
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

# Check if plain HTTP port is open
skip_checks = false
if ! is_port_open?($host, $port)
  # skip all metric checks
  skip_checks = true
  results << {'text' => "CRITICAL: Could not connect to plain HTTP port #{$host}:#{$port}", 'returncode' => 2}
end

# Check if plain SSL port is open
if ! is_port_open?($host, $sslport)
  # don't skip metric checks, but add CRITICAL result
  results << {'text' => "CRITICAL: Could not connect to SSL port #{$host}:#{$sslport}", 'returncode' => 2}
end

$api_version = checkApiVersion()
puts "found PuppetDB API version #{$api_version}" if $debug

if ! skip_checks
  if $debug == false
    # threading
    threads = []
    threads << Thread.new{ results << commandProcessingMetrics($cmd_p_secwarn, $cmd_p_seccrit) }
    threads << Thread.new{ results << commandProcessedMetrics() }
    threads << Thread.new{ results << commandRetriedMetrics() }
    if $api_version == 4
      threads << Thread.new{ results << databaseMetricsHikari() }
      threads << Thread.new{ results << databaseMetricsHikari('Read') }
    else
      threads << Thread.new{ results << databaseMetrics() }
    end
    threads << Thread.new{ results << JvmMetrics() }
    threads << Thread.new{ results << queueMetrics($queuewarn, $queuecrit) }
    threads << Thread.new{ results << catalogDuplicatesMetrics() }
    threads << Thread.new{ results << populationNodesMetrics() }
    # I only began querying this after updating to PuppetDB 1.6, otherwise it was too slow
    threads << Thread.new{ results << populationResourcesMetrics() }
    # This is also rather costly (adds more than 2 seconds for me)
    threads << Thread.new{ results << resourceDuplicatesMetrics() }

    threads.each do |t|
      t.join
    end
  else
    results << commandProcessingMetrics($cmd_p_secwarn, $cmd_p_seccrit)
    results << commandProcessedMetrics()
    results << commandRetriedMetrics()
    if $api_version == 4
      results << databaseMetricsHikari()
      results << databaseMetricsHikari('Read')
    else
      results << databaseMetrics()
    end
    results << JvmMetrics()
    results << queueMetrics($queuewarn, $queuecrit)
    results << catalogDuplicatesMetrics()
    results << populationNodesMetrics()
    # I only began querying this after updating to PuppetDB 1.6, otherwise it was too slow
    results << populationResourcesMetrics()
    # This is also rather costly (adds more than 2 seconds for me)
    results << resourceDuplicatesMetrics()
  end
end

puts results if $debug

# Aggregate check results
output = {}
output['returncode'] = 0
output['text'] = ''
output['text_if_ok'] = ''
output['multiline'] = ''
output['perfdata'] = ''
puppetdb_still_alive = false
results.each do |result|
  output['perfdata'] += "#{result['perfdata']} " if result['perfdata'] != ''
  if result['returncode'] >= 1
    if ! result['text'].start_with?('Error \'Timeout::Error\' while sending ') and ! puppetdb_still_alive
      puppetdb_still_alive = true
    else
      puppetdb_still_alive = false
    end
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
    puppetdb_still_alive = true
    output['text_if_ok'] += "#{result['text']} "
    br = ''
    br = '</br>' if $checkmk
    output['multiline'] += "#{result['text']}#{br}\n"
  end
end

# if all check receive a timeout error then the PuppetDB is non functioning
if ! puppetdb_still_alive
  output['text'] = 'CRITICAL: Received only timeout errors, PuppetDB is not responding anymore, try restarting'
  output['returncode'] = 2
end

if output['text'] == ''
  output['text'] = output['text_if_ok']
end

puts "#{output['text']}|#{output['perfdata']}\n#{output['multiline'].chomp()}"

exit output['returncode']
