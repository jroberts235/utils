module NukeIt
   
    class Nuke < Chef::Knife
        banner "Delete a server from Chef, Openstack, Ec2 and Sensu"
         
        deps do
          require 'chef/search/query'
        end
   
        def run
            if name_args.size == 1
                node = name_args.first
                
                #confirm before doing anything
                ui.msg "Nuke #{node}, Are you sure? (yes/no) "
                a = $stdin.gets.chomp
                if "#{a}" != "yes"
                    exit
                end

            else
                ui.fatal "Please provide a node name to nuke"
                exit 1
            end
  
            query = "name:#{node}"
            query_nodes = Chef::Search::Query.new
   
            query_nodes.search('node', query) do |node_item|
            ui.msg "Nukin' the son of a bitch!"
              
            # Sensu
            if node_item.has_key?('sensu')
  	             puts "Removing #{node} from monitoring"

                require 'rest_client'
                RestClient.delete("http://sensu.ops.nastygal.com:4567/client/#{node}") { |response, request, result, &block|
                    case response.code
                    when 200
                      puts "  Got a 200 from sensu API"
                      #response
                    when 423
                      raise "ERROR: Got a 4xx code from the Sensu API"
                    else
                      response.return!(request, result, &block)
                    end
                }
  	         else
  	             puts "Doesn't seem to be in monitored"
            end
  
            # Ec2
   	      if node_item.has_key?('ec2')
              r = node_item['ec2']['placement_availability_zone']
              region = r[0..-2]
              system("knife ec2 server delete --region #{region} #{node_item['ec2']['instance_id']} -y")
            else
              puts 'Doesn\'t seem to be an ec2 instance'
  	         end

            # Openstack
            puts "Deleting from Openstack"
            system("/usr/local/bin/nova delete #{node}")
  
            # Chef
            puts "Removing #{node} from chef server"
            system("knife node delete #{node} -y") 
            system("knife client delete #{node} -y") 
            end
        end
    end
end
