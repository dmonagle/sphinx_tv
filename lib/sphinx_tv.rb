require "colorize"
require "etc"
require "yaml"
require 'optparse'
require "highline/import"
require "modules/sphinx_module"
require "sphinx_tv/download"
require "sphinx_tv/cpan"
require "erb"
require "version"

class SphinxTv
  SUDO_PROMPT = "-p \"#{"Your administrator password is required to peform this step: ".yellow}\""
  CONFIG_DIRECTORY = File.join(Etc.getpwuid.dir, ".sphinx_tv")
  MODULES = ["MySQL", "MythTv", "Shepherd"]
  MODULE_DEFAULTS = {
      "MySQL" => {
          :active => true,
          :setup => false,
          :configure => true,
      },
      "MythTv" => {
          :active => true,
          :setup => false,
          :configure => true,
          :depends => ["MySQL"],
      },
      "Shepherd" => {
          :active => false,
          :setup => false,
          :configure => true,
          :depends => ["MythTv"],
      },
  }

  def initialize
    @config = {
        :version => SphinxTv::VERSION,
        :modules => MODULE_DEFAULTS
    }
  end

  def self.root_directory
    File.expand_path '../..', __FILE__
  end

  def self.resources_path(file = "")
    File.join(root_directory, "resources", file)
  end

  def self.download_path(file = "")
    download_directory = File.join(CONFIG_DIRECTORY, "downloads")
    Dir.mkdir(download_directory) unless File.exists? download_directory
    return File.join(download_directory, file)
  end

  def self.cache_path(file = "")
    cache_directory = File.join(CONFIG_DIRECTORY, "cache")
    Dir.mkdir(cache_directory) unless File.exists? cache_directory
    return File.join(cache_directory, file)
  end

  def self.copy_template(source, dest, b)
    t = ERB.new File.new(source).read, nil, "%"
    outfile = File.open(dest, "w")
    outfile.write(t.result(b || binding))
    outfile.close
  end

  def self.get_password_with_confirmation(prompt = nil)
    pass = ask(prompt || "Enter a password: ") { |q| q.echo = "*" }
    pass_confirm = ask("Re-enter the password: ") { |q| q.echo = "*" }
    if pass != pass_confirm
      puts "Passwords do not match!".red
      return nil
    end
    pass
  end

  def load_configuration
    config_file = File.join(CONFIG_DIRECTORY, "sphinx.yml")
    unless File.exists? config_file
      puts "Configuration file does not exist. Using defaults.".yellow
      return false
    end
    c = YAML::load_file config_file
    @config.merge! c
    return true
  end

  def save_configuration
    File.open(File.join(CONFIG_DIRECTORY, "sphinx.yml"), "w") do |file|
      file.write @config.to_yaml
    end
  end

  def module_select
    exit = false
    until exit do
      choose do |menu|
        menu.header = "\nSelect Modules".cyan
        menu.prompt = "Select optional modules to toggle: "
        MODULES.each do |m|
          options = @config[:modules][m]
          menu.choice("#{m}: " + (options[:active] ? "On".green : "Off".red)) do |choice|
            m = /^([^:]*)/.match(choice)[0]
            toggle_module m
          end
        end
        menu.choice(:done) {
          exit = true
        }
      end
    end
  end

  def toggle_module(m)
    options = @config[:modules][m]

    options[:active] = !options[:active]
    if (options[:active])
      if (options[:depends])
        options[:depends].each do |d|
          toggle_module d unless @config[:modules][d][:active]
        end
      end
    end
  end

  def module_menu(action, title)
    exit = false
    until exit do
      choose do |menu|
        menu.header = "\n#{title}".cyan
        menu.prompt = "Select a module: "
        MODULES.each do |m|
          options = @config[:modules][m]
          if (options[action])
            menu.choice(m) do |m|
              require File.join("modules", m)
              mod = eval("#{m}.new")
              mod.send(action)
            end
          end
        end
        menu.choice(:done) {
          exit = true
        }
      end
    end
  end

  def run_selected_modules &block
    MODULES.each do |m|
      if @config[:modules][m][:active]
        require File.join("modules", m)
        mod = eval("#{m}.new")
        yield mod
      end
    end
  end

  def setup
    exit = false
    until exit do
      choose do |menu|
        menu.header = "\nSphinx Installer".cyan
        menu.prompt = "Select an option: "

        menu.choice("Select Modules") { module_select }
        menu.choice("Setup Modules") { module_menu(:setup, "Module Setup") }
        menu.choice("Save Configuration") {
          save_configuration
          puts "Configuration Saved.".green
          exit = true
        }
        menu.choice("Cancel") {
          puts "Exiting without saving configuration.".red
          exit = true
        }
      end
    end
  end

  def run
    Dir.mkdir(CONFIG_DIRECTORY) unless File.exists? CONFIG_DIRECTORY
    @no_config = load_configuration

    action = nil

    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top
      # of the help screen.
      opts.banner = "Usage: sphinx [options] action"

      # This displays the help screen, all programs are
      # assumed to have this option.
      opts.on('-h', '--help', 'Display this screen') do
        puts opts
        exit
      end
    end

    # Parse the command-line. Remember there are two forms
    # of the parse method. The 'parse' method simply parses
    # ARGV, while the 'parse!' method parses ARGV and removes
    # any options found there, as well as any parameters for
    # the options. What's left is the list of files to resize.
    optparse.parse!
    # Set the selected modules unless it was overridden

    action = ARGV[0]
    case action
      when "setup"
        setup
      when "configure"
        module_menu(:configure, "Configure Modules")
      when "check"
        run_selected_modules { |m| m.check }
      when "install"
        run_selected_modules { |m| m.install }
      when "uninstall"
        run_selected_modules { |m| m.uninstall }
      when "download"
        run_selected_modules { |m| m.download }
      when "update"
        run_selected_modules { |m| m.update }
      else
        puts "Use the --help switch if you need a list of valid actions"
    end
  end

end