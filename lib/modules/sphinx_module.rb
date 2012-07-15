class SphinxModule
  def initialize
    @config = {
        :version => SphinxTv::VERSION
    }
  end

  def load_configuration
    config_file = File.join(SphinxTv::CONFIG_DIRECTORY, "#{self.class.to_s.downcase}.yml")
    unless File.exists? config_file
      return false
    end
    c = YAML::load_file config_file
    @config.merge! c
    return true
  end

  def save_configuration
    def save_configuration
      Dir.mkdir(SphinxTv::CONFIG_DIRECTORY) unless File.exists? SphinxTv::CONFIG_DIRECTORY
      File.open(File.join(SphinxTv::CONFIG_DIRECTORY, "#{self.class.to_s.downcase}.yml"), "w") do |file|
        file.write @config.to_yaml
      end
    end
  end

  def check(quiet = false)
    return true
  end

  def setup
    puts "#{self.class.to_s} does not have a setup menu.".red
    return false
  end

  def configure
    puts "#{self.class.to_s} does not have a configuration menu.".red
    return false
  end

  def download
  end

  def install
    puts "#{self.class.to_s} does not have an install function.".red
  end

  def uninstall
    puts "#{self.class.to_s} does not have an uninstall function.".red
  end

  def update
    puts "#{self.class.to_s} does not have an update function.".red
  end
end