#!/usr/bin/env ruby

# This script traverses the Chef server and find nodes that have not run chef-client in over 1hrs.
# It pulls the IP and fqdn of the node and tests to see if the node is up and in dns.

require 'ridley'
require 'net/ping'
require 'dnsruby'


def ping_test(node)
  begin
    p1 = Net::Ping::External.new(node)
    p1.ping
  rescue ArgumentError
    return false
  end
end


def dns_test(fqdn, chef_ip)
  begin
  resolve =  Dnsruby::DNS.new
  dns_ip = (resolve.getaddress(fqdn)).to_s
  dns_ip == chef_ip
  rescue
    return false
  end
end


def node_data(node_name='*')
  node_data_h = {} 

  Celluloid.logger = nil # Silence annoying debug info from Celluloid

  ridley = Ridley.from_chef_config
  ret_a = ridley.search(:node, "name:#{node_name}")
  ret_a.each do |node|
  metadata_h = {}
    begin
      metadata_h[:ipaddress] = node.instance_variable_get(:@_attributes_)[:automatic].ipaddress
           metadata_h[:fqdn] = node.instance_variable_get(:@_attributes_)[:automatic].fqdn
               last_chef_run = node.instance_variable_get(:@_attributes_)[:automatic].ohai_time
                   node_name = node.instance_variable_get(:@_attributes_).name 
 
      if last_chef_run
         last_in_ascii = Time.at(last_chef_run) 
        delta_in_hours = (( Time.now.to_i - Time.at(last_in_ascii).to_i ) / 60 / 60)
        delta_in_hours > 1 ? ( metadata_h[:last_run_in_hrs] = delta_in_hours ) : next
      else
        delta_in_hours = "nil" 
      end
  
      node_data_h[node_name] = metadata_h
                       
    rescue TypeError => e
      metadata_h[error] = e
      next
    end
  end
  return node_data_h
end


begin
  output_a = []
  
  nodes_to_test = node_data() # put a single node name here to test
  nodes_to_test.each do |node| 

    node_values_a = []
    node_data_h = {}

    node_name = node[0]
    ip = node[1][:ipaddress] 
    fqdn = node[1][:fqdn]
    last_chef_run = node[1][:last_run_in_hrs]

    ping_test(ip)      ? pingable     = "Yes" : pingable     = "No"   
    dns_test(fqdn, ip) ? ip_match_dns = "Yes" : ip_match_dns = "No"
    
    node_values_a.push(pingable, ip_match_dns, last_chef_run)
    node_data_h[node_name] = node_values_a
    output_a.push(node_data_h)
  end
  puts "Nodes not running chef-client"
  puts
  printf("%-20s %18s %19s %15s \n", 'Node Name', 'Pingable?', 'DNS Matches Chef', 'Last Run(hrs)') 
  75.times { print '-' } ; puts
  output_a.each do |line|
    line.each do |k,v|
      printf("%-20s %15s %15s %15s \n", k, v[0], v[1], v[2]) 
    end
  end
end
