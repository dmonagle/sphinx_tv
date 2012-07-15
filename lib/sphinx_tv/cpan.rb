require 'expect'
require 'pty'

class Cpan
  def self.install modules
    modules.each do |m|
      result = %x[perl -M#{m} -e 1 2>&1].strip
      if result.empty?
        puts "Module '#{m}' is installed".green
      else
        puts "Installing perl module: #{m}".cyan
        system("sudo #{Sphinx::SUDO_PROMPT} cpan -j #{Sphinx::cache_path("MyConfig.pm")} -f -i #{m}")
      end
    end
  end

  def self.create_config_file
    unless File.exists? Sphinx::cache_path("MyConfig.pm")
      puts "Creating cpan config...".cyan

      @cache_dir = Sphinx::cache_path
      Sphinx::copy_template(Sphinx::resources_path("MyConfig.pm.erb"), Sphinx::cache_path("MyConfig.pm"), binding)
    end
  end

end