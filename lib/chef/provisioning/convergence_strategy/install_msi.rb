require 'chef/provisioning/convergence_strategy/precreate_chef_objects'
require 'mixlib/install'
require 'pathname'

class Chef
module Provisioning
  class ConvergenceStrategy
    class InstallMsi < PrecreateChefObjects
      def initialize(convergence_options, config)
        super
        @chef_version ||= convergence_options[:chef_version]
        @prerelease ||= convergence_options[:prerelease]
        @chef_client_timeout = convergence_options.has_key?(:chef_client_timeout) ? convergence_options[:chef_client_timeout] : 120*60 # Default: 2 hours
      end

      attr_reader :chef_version
      attr_reader :prerelease
      attr_reader :install_msi_url
      attr_reader :install_msi_path

      def setup_convergence(action_handler, machine)
        if !convergence_options.has_key?(:client_rb_path) || !convergence_options.has_key?(:client_pem_path)
          system_drive = machine.execute_always('$env:SystemDrive').stdout.strip
          @convergence_options = Cheffish::MergedConfig.new(convergence_options, {
            :client_rb_path => "#{system_drive}\\chef\\client.rb",
            :client_pem_path => "#{system_drive}\\chef\\client.pem"
          })
        end

        opts = {"prerelease" => prerelease}
        if convergence_options[:bootstrap_proxy]
          opts["http_proxy"] = convergence_options[:bootstrap_proxy]
          opts["https_proxy"] = convergence_options[:bootstrap_proxy]
        end
        super

        install_command = Mixlib::Install.new(chef_version, true, opts).install
        machine.execute(action_handler, install_command)
      end

      def converge(action_handler, machine)
        super

        action_handler.open_stream(machine.node['name']) do |stdout|
          action_handler.open_stream(machine.node['name']) do |stderr|
            command_line = "chef-client"
            command_line << " -l #{config[:log_level].to_s}" if config[:log_level]
            machine.execute(action_handler, command_line,
              :stream_stdout => stdout,
              :stream_stderr => stderr,
              :timeout => @chef_client_timeout)
          end
        end
      end

    end
  end
end
end
