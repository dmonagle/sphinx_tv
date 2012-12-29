class MySQL < SphinxModule
  def check(quiet = false)
    result = true
    unless mysql_installed?
      result = false
      puts "The MySQL server doesn't appear to be installed.'".red unless quiet
    end
    unless File.exists? "/etc/paths.d/mysql"
      result = false
      puts "MySQL paths.d file is not configured.".red unless quiet
    end
    unless File.exists? "/usr/lib/libmysqlclient.18.dylib"
      result = false
      puts "MySQL does not have a symbolic link set up for the libmysqlclient dynlib.".red unless quiet
    end
    unless File.exists? "/var/mysql/mysql.sock"
      result = false
      puts "MySQL socket does not exist.".red unless quiet
    end

    puts "MySQL is OK.".green if result
    result
  end

  def configure
    unless mysql_installed?
      puts "\nOnce you have MySQL installed, you may return to this menu to setup root access\n"
    end
    exit = false
    until exit do
      choose do |menu|
        menu.header = "\nMySQL Configuration".cyan
        menu.prompt = "Select an option: "
        if mysql_installed?
          menu.choice("Setup root access") { set_mysql_root_access }
        end
        menu.choice("Done") {
          exit = true
        }
      end
    end
  end

  def download
    url = "http://cdn.mysql.com/Downloads/MySQL-5.5/mysql-5.5.29-osx10.6-x86_64.dmg"
    puts "Downloading MySQL".cyan
    puts url
    result = Download.url(url, SphinxTv::download_path("mysql.dmg"))
  end

  def install
    puts "Installing MySQL".cyan
    unless check(true)
      download
      Download.mount(SphinxTv::download_path("mysql.dmg"), "mysql*") do |volume|
        self.install_mysql_server volume
        self.install_mysql_prefpane volume
        self.install_mysql_startup volume
      end
    else
      puts "MySQL is installed.".green
    end
  end

  protected

  def mysql_installed?
    File.exists?("/usr/local/mysql/bin/mysql")
  end

  def install_mysql_server volume
    puts "Installing MySQL Server".cyan
    puts "This will configure the MySQL server. A graphical installer should open now."
    files = Dir.glob File.join(volume, "mysql*")
    if (files.size == 0)
      puts "Could not find installer file in volume #{volume}".red
      return
    end
    %x[open #{files[0]}]
    ask "\nPress enter when the install is complete!".magenta

    # Create the paths.d file
    if mysql_installed?
      puts "Creating global path file /etc/paths.d/mysql".cyan
      %x[sudo #{SphinxTv::SUDO_PROMPT} bash -c 'echo "/usr/local/mysql/bin" > /etc/paths.d/mysql']
    end

    # Create the symbolic link to the client library
    unless File.exists? "/usr/lib/libmysqlclient.18.dylib"
      puts "Linking dynamic libraries".cyan
      %x[sudo #{SphinxTv::SUDO_PROMPT} ln -s /usr/local/mysql/lib/libmysqlclient.18.dylib /usr/lib]
    end

    # Create the mysql socket
    unless File.exists? "/tmp/mysql.sock"
      puts "Creating link to mysql socket".cyan
      %x[sudo #{SphinxTv::SUDO_PROMPT} mkdir -p /var/mysql]
      %x[sudo #{SphinxTv::SUDO_PROMPT} ln -s /tmp/mysql.sock /var/mysql/]
    end
  end

  def install_mysql_prefpane volume
    puts "Installing MySQL Prefpane\n".cyan
    puts "Select the option to install for all users of the computer"
    puts "On the Prefpane, tick the option to start the MySQL Server on Startup"
    puts "Click the button to start the MySQL Server"
    files = Dir.glob File.join(volume, "MySQL.prefpane")
    if (files.size == 0)
      puts "Could not find Prefpane file in volume #{volume}".red
      return
    end
    %x[open #{files[0]}]
    ask "\nPress enter when the install is complete!".magenta
  end

  def install_mysql_startup volume
    puts "Installing MySQL Startup".cyan
    files = Dir.glob File.join(volume, "MySQLStartup*")
    if (files.size == 0)
      puts "Could not find startup installer file in volume #{volume}".red
      return
    end
    %x[open #{files[0]}]
    ask "\nPress enter when the install is complete!".magenta
  end

  def set_mysql_root_access
    puts "This will allow you to set the root password for your database.".yellow
    puts "It will give you a more secure SQL server on your network but if you lose".yellow
    puts "the root password at any point, it will cause you pain.".yellow
    response = ask("Set up root privileges? ") { |q| q.default = "No" }
    return if !/Y/i.match(response)
    old_root_pass = ask("Enter the current root password: ") { |q| q.echo = "*" }
    root_pass = ask("Enter the new root password: ") { |q| q.echo = "*" }
    root_pass_confirm = ask("Re-enter the new root password: ") { |q| q.echo = "*" }
    if root_pass != root_pass_confirm
      puts "Passwords do not match!".red
      return
    end
    hostname = %x[hostname].strip
    hostname_short = /^[^\.]+/.match(hostname)
    mysql_commands = Array.new.tap do |c|
      c << "DROP USER ''@'localhost';" if old_root_pass.empty?
      c << "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('#{root_pass}');"
      c << "SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('#{root_pass}');"
      c << "SET PASSWORD FOR 'root'@'#{hostname}' = PASSWORD('#{root_pass}');"
      c << "SET PASSWORD FOR 'root'@'#{hostname_short}' = PASSWORD('#{root_pass}');"
    end
    password_param = old_root_pass.empty? ? "" : " --password=#{old_root_pass}"
    mysql_commands.each do |sql|
      puts sql
      %x[/usr/local/mysql/bin/mysql -u root#{password_param} -e "#{sql}"]
    end
  end
end