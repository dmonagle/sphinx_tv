require 'nokogiri'
require 'open-uri'

class MythTv < SphinxModule
  def initialize
    @config = {
        :version => SphinxTv::VERSION
    }
    load_configuration
  end

  def check(quiet = false)
    result = true
    result = false unless mythtv_backend_installed?(quiet)
    result = false unless mythtv_frontend_installed?(quiet)
    unless @config[:database_password]
      result = false
      puts "Assuming no database is set up as the MythTV database password is not set.'".red unless quiet
    end
    unless File.exists? "/usr/local/bin/mythfilldatabase"
      result = false
      puts "No symbolic link to mythfilldatabase found".red unless quiet
    end

    puts "MythTV is OK.".green if result
    result
  end

  def configure
    exit = false
    until exit do
      choose do |menu|
        menu.header = "\nMythTV Configuration".cyan
        menu.prompt = "Select an option: "
        if mythtv_backend_installed?
          menu.choice("Setup database") { setup_database }
        end
        menu.choice("Create Storage Directories") { create_storage_directories }
        if mythtv_backend_running?
          menu.choice("MythTV Backend Control " + "Loaded".green) { mythtv_backend_control(false) }
        else
          menu.choice("MythTV Backend Control " + "Unloaded".red) { mythtv_backend_control(true) }
        end
        menu.choice("Done") {
          exit = true
        }
      end
    end
  end

  def download
    doc = Nokogiri::HTML(open('http://sourceforge.net/projects/mythtvformacosx/files/'))

    doc.css('tr.file  a').each do |link|
      if /\.dmg\/download$/.match(link[:href])
        filename = nil
        if /MythBack.*10\.7/.match(link[:href])
          filename = "MythBackend.dmg"
        elsif /MythFront.*10\.7/.match(link[:href])
          filename = "MythFrontend.dmg"
        end
        if filename
          puts "Downloading #{filename}".cyan
          puts link[:href]
          Download::url(link[:href], SphinxTv::download_path(filename))
        end
      end
    end
  end

  def install
    puts "Installing MythTV".cyan
    unless check(true)
      download
      install_mythtv_backend unless mythtv_backend_installed?
      install_mythtv_frontend unless mythtv_frontend_installed?

      unless File.exists? "/usr/local/bin/mythfilldatabase"
        puts "Creating link to mythfilldatabase".cyan
        %x[sudo #{SphinxTv::SUDO_PROMPT} mkdir -p /usr/local/bin]
        %x[sudo #{SphinxTv::SUDO_PROMPT} ln -s /Applications/MythBackend.app/Contents/MacOS/mythfilldatabase /usr/local/bin/mythfilldatabase]
      end
    end
  end

  private

  def mythtv_backend_running?
    result = %x[ps ax | grep MythBackend | grep -v grep]
    return false if result.strip.empty?
    true
  end

  def mythtv_backend_control(load)
    %x[sudo #{SphinxTv::SUDO_PROMPT} launchctl #{load ? "load" : "unload"} -w /Library/LaunchDaemons/MythBackend.plist]
  end

  def mythtv_frontend_installed?(quiet = true)
    result = true
    unless File.exists? "/Applications/MythFrontend.app"
      result = false
      puts "MythFrontend application not installed.".red unless quiet
    end
    result
  end

  def mythtv_backend_installed?(quiet = true)
    result = true
    unless File.exists? "/Applications/MythBackend.app"
      result = false
      puts "MythBackend application not installed.".red unless quiet
    end
    unless File.exists? "/Library/LaunchDaemons/MythBackend.plist"
      result = false
      puts "MythBackend LaunchDaemon does not exist.".red unless quiet
    end
    result
  end

  def install_mythtv_backend
    Download.mount(SphinxTv::download_path("MythBackend.dmg"), "MythBackend*") do |volume|
      puts "Installing MythTVBackend".cyan
      mythtv_files = ["MythBackend.app", "MythTv-Setup.app"]
      mythtv_files.each do |file|
        %x[cp -Rf #{volume}/#{file} /Applications 2>&1]
      end
      @username = Etc.getlogin
      unless File.exists? "/var/log/mythtv"
        puts "Creating MythTV log directory...".cyan
        %x[sudo #{SphinxTv::SUDO_PROMPT} mkdir -p /var/log/mythtv]
        %x[sudo #{SphinxTv::SUDO_PROMPT} chmod a+rwx /var/log/mythtv]
      end

      puts "Creating MythBackend LaunchDaemon file...".cyan
      SphinxTv::copy_template(SphinxTv::resources_path("MythTv/MythBackend.plist.erb"), SphinxTv::cache_path("MythBackend.plist"), binding)
      %x[sudo #{SphinxTv::SUDO_PROMPT} cp #{SphinxTv::cache_path("MythBackend.plist")} /Library/LaunchDaemons]
    end
  end

  def install_mythtv_frontend
    Download.mount(SphinxTv::download_path("MythFrontend.dmg"), "MythFrontend*") do |volume|
      puts "Installing MythTVFrontend".cyan
      mythtv_files = ["MythFrontend.app", "MythWelcome.app", "MythAVTest.app"]
      mythtv_files.each do |file|
        %x[cp -Rf #{volume}/#{file} /Applications 2>&1]
      end
    end
  end

  def setup_database
    puts "This will create the MythTV database if it doesn't already exist and set appropriate privileges."
    root_pass = ask("Enter your mysql root password: ") { |q| q.echo = "*" }
    @config[:database_password] ||= SphinxTv::get_password_with_confirmation("Enter a password for the mythtv MySQL user: ")
    return if @config[:database_password].nil?
    save_configuration
    hostname = %x[hostname].strip
    hostname_short = /^[^\.]+/.match(hostname)
    mysql_commands = Array.new.tap do |c|
      c << "CREATE DATABASE IF NOT EXISTS mythconverg;"
      c << "GRANT ALL ON mythconverg.* TO mythtv@localhost IDENTIFIED BY '#{@config[:database_password]}';"
      c << "GRANT ALL ON mythconverg.* TO mythtv@#{hostname} IDENTIFIED BY '#{@config[:database_password]}';"
      c << "FLUSH PRIVILEGES;"
      c << "GRANT CREATE TEMPORARY TABLES ON mythconverg.* TO mythtv@localhost IDENTIFIED BY '#{@config[:database_password]}';"
      c << "GRANT CREATE TEMPORARY TABLES ON mythconverg.* TO mythtv@#{hostname} IDENTIFIED BY '#{@config[:database_password]}';"
      c << "FLUSH PRIVILEGES;"
      c << "ALTER DATABASE mythconverg DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
    end
    password_param = root_pass.empty? ? "" : " --password=#{root_pass}"
    mysql_commands.each do |sql|
      puts sql
      %x[/usr/local/mysql/bin/mysql -u root#{password_param} -e "#{sql}"]
    end

    puts "Creating mysql.txt in /etc/mythtv".cyan
    %x[sudo #{SphinxTv::SUDO_PROMPT} mkdir -p /etc/mythtv]
    %x[sudo #{SphinxTv::SUDO_PROMPT} chmod a+rwx /etc/mythtv]
    outfile = File.open("/etc/mythtv/mysql.txt", "w")
    outfile.puts("DBHostName=#{hostname}")
    outfile.puts("DBUserName=mythtv")
    outfile.puts("DBPassword=#{@config[:database_password]}")
    outfile.puts("DBName=mythconverg")
    outfile.puts("DBType=QMYSQL3")
    outfile.close
    %x[chmod o-w /etc/mythtv/mysql.txt]
  end

  def create_storage_directories
    storage_root = ask("Enter the storage directory root: ") { |q| q.default = "/Volumes/MythTV" }
    directories = ['Backups', 'Banners', 'Coverart', 'Fanart', 'LiveTV', 'Recordings', 'Screenshots', 'Trailers']
    directories.each do |directory|
      full_dir = File.join(storage_root, directory)
      puts full_dir
      %x[sudo #{SphinxTv::SUDO_PROMPT} mkdir -p #{full_dir}]
    end
    %x[sudo #{SphinxTv::SUDO_PROMPT} chown -Rf #{Etc.getlogin} #{storage_root}]
    %x[sudo #{SphinxTv::SUDO_PROMPT} chmod -Rf ugo+rwx #{storage_root}]
  end
end