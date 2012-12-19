require "erb"

String.class_eval do
  def camel_case
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    s = gsub("-", "_")
    s.split('_').map{|e| e.capitalize}.join
  end
end

module Reacg
  module Generators
    class Ruby
      # All Generators must implement this method.
      # A hash of the reacg options is passed in.
      def self.create_client(config)
        @config = config

        setup_directories
        create_gem_skeleton
        create_gem_file
        create_gemspec
        require_classes
        create_classes
        package_gem
        cleanup
      end

      private
      def self.setup_directories
        FileUtils.rm_rf 'tmp'
        Dir.mkdir("build") unless File.exists?("build")
        Dir.mkdir("tmp")
        Dir.chdir("tmp")
      end

      def self.create_gem_skeleton
        system "bundle gem #{@config["name"]}"
        Dir.chdir(@config["name"])
      end

      def self.create_gem_file
        @gems = [{:name => "activeresource", :version => "~> 3.2.8"}]
        create_file_from_template("gemfile.erb", "Gemfile")
      end

      def self.create_file_from_template(template, filename)
        template = File.expand_path("../templates/#{template}", __FILE__)
        begin
          t = ERB.new IO.read template
          File.open(filename, "w") do |f|
            f.write (t.result(binding)).gsub /^$\n/, ''
          end
        rescue Errno::ENOENT
          raise "Could not locate template file: #{template}"
        end
      end

      def self.require_classes
        Dir.chdir("lib")
        @dependencies = ['active_resource', "#{@config['name']}/base.rb"]
        create_file_from_template("client.erb", "#{@config['name']}.rb")
      end

      def self.create_classes
        Dir.chdir(@config["name"])
        @class = { :modules => [@config['name'].camel_case],
                   :name => "Base",
                   :super_class_name => "::ActiveResource::Base",
                   :attributes => [],
                   :validations => [] }

        # Create Base Class
        create_file_from_template("class.erb", "base.rb")

        # Create Resource Classes
        @class[:super_class_name] = "Base"
        @config["resources"].each do |name, options|
          @class[:name] = name.camel_case
          create_file_from_template("class.erb", "#{name}.rb")
        end
      end

      def self.package_gem
        Dir.chdir("../..")
        system "gem build #{@config['name']}.gemspec"
        FileUtils.mv("#{@config['name']}-0.0.1.gem", '../../build')
      end

      def self.cleanup
        FileUtils.rm_rf 'tmp'
      end

      def self.create_gemspec
        @gemspec = {:name => @config['name'],
                    :version => @config['version'],
                    :dependencies => [{:name => "activeresource",
                                       :version => "~> 3.2.8"}]}
        create_file_from_template("gemspec.erb", "#{@config['name']}.gemspec")
      end

    end
  end
end