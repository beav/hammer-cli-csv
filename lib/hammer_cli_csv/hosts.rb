module HammerCLICsv
  class CsvCommand
    class HostsCommand < BaseCommand
      command_name 'hosts'
      desc         'import or export hosts'

      ORGANIZATION = 'Organization'
      LOCATION = 'Location'
      ENVIRONMENT = 'Environment'
      OPERATINGSYSTEM = 'Operating System'
      ARCHITECTURE = 'Architecture'
      MACADDRESS = 'MAC Address'
      DOMAIN = 'Domain'
      PARTITIONTABLE = 'Partition Table'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATION, LOCATION, ENVIRONMENT, OPERATINGSYSTEM, ARCHITECTURE, MACADDRESS, DOMAIN, PARTITIONTABLE]
          search_options = {:per_page => 999999}
          search_options['search'] = "organization = #{option_organization}" if option_organization
          @api.resource(:hosts).call(:index, search_options)['results'].each do |host|
            host = @api.resource(:hosts).call(:show, {'id' => host['id']})
            raise "Host 'id=#{host['id']}' not found" if !host || host.empty?

            name = host['name']
            count = 1
            organization = foreman_organization(:id => host['organization_id'])
            environment = foreman_environment(:id => host['environment_id'])
            operatingsystem = foreman_operatingsystem(:id => host['operatingsystem_id'])
            architecture = foreman_architecture(:id => host['architecture_id'])
            mac = host['mac']
            domain = foreman_domain(:id => host['domain_id'])
            ptable = foreman_partitiontable(:id => host['ptable_id'])

            csv << [name, count, organization, environment, operatingsystem, architecture, mac, domain, ptable]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:hosts).call(:index, {:per_page => 999999})['results'].each do |host|
          @existing[host['name']] = host['id'] if host
        end

        thread_import do |line|
          create_hosts_from_csv(line)
        end
      end

      def create_hosts_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating host '#{name}'..." if option_verbose?
            @api.resource(:hosts).call(:create, {
                'host' => {
                  'name' => name,
                  'root_pass' => 'changeme',
                  'mac' => namify(line[MACADDRESS], number),
                  'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                  'location_id' => foreman_location(:name => line[LOCATION]),
                  'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                  'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
                  'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
                  'domain_id' => foreman_domain(:name => line[DOMAIN]),
                  'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
                }
            })
          else
            print "Updating host '#{name}'..." if option_verbose?
            @api.resource(:hosts).call(:update, {
                'id' => @existing[name],
                'host' => {
                  'name' => name,
                  'mac' => namify(line[MACADDRESS], number),
                  'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                  'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                  'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
                  'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
                  'domain_id' => foreman_domain(:name => line[DOMAIN]),
                  'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
                }
            })
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
