class Shepherd < SphinxModule
  def initialize
    @config = {
        :version => SphinxTv::VERSION
    }
    load_configuration
  end

  def check(quiet = false)
    result = true

    unless File.exists? "/usr/local/share/xmltv"
      result = false
      puts "XMLTV is not installed.".red unless quiet
    end

    unless File.exists? File.join(Etc.getpwuid.dir, ".shepherd")
      result = false
      puts "Shepherd is not installed.".red unless quiet
    end

    puts "Shepherd is OK.".green if result
    result
  end

  def configure
    shepherd = File.join(Etc.getpwuid.dir, ".shepherd", "shepherd")
    shepherd_download = SphinxTv::download_path("shepherd")
    exit = false
    until exit do
      choose do |menu|
        menu.header = "\nShepherd Configuration".cyan
        menu.prompt = "Select an option: "
        if File.exists? shepherd
          menu.choice("Configure Shepherd") { system("perl #{shepherd} --configure") }
        elsif File.exists? shepherd_download
          menu.choice("Install and Configure Shepherd") { system("perl #{shepherd_download} --configure") }
        end
        menu.choice("Done") {
          exit = true
        }
      end
    end
  end

  def download
    doc = Nokogiri::HTML(open('http://sourceforge.net/projects/xmltv/files/xmltv/0.5.63/'))

    url = "http://www.whuffy.com/shepherd/shepherd"
    puts "Downloading Shepherd".cyan
    puts url
    result = Download.url(url, SphinxTv::download_path("shepherd"))

    doc.css('tr.file  a').each do |link|
      if /\.tar\.bz2\/download$/.match(link[:href])
        filename = nil
        filename = "xmltv.tar.bz2" if /xmltv/.match(link[:href])
        if filename
          puts "Downloading #{filename}".cyan
          puts link[:href]
          Download::url(link[:href], SphinxTv::download_path(filename))
        end
      end
    end
  end

  def install
    unless check(true)
      download
      install_perl_prerequisites
      install_xmltv unless File.exists? "/usr/local/share/xmltv"

      unless File.exists? "/Library/Perl/5.12/Shepherd"
        puts "Creating symlink for Shepherd/MythTV perl library...".cyan
        home_dir = Etc.getpwuid.dir
        %x[sudo #{SphinxTv::SUDO_PROMPT} ln -s #{home_dir}/.shepherd/references/Shepherd /Library/Perl/5.12]
      end
    end
  end

  def install_perl_prerequisites

    Cpan::create_config_file

    shepherd_mandatory_perl_modules = "YAML XML::Twig Algorithm::Diff Compress::Zlib Cwd Data::Dumper Date::Manip Getopt::Long \
         List::Compare LWP::UserAgent POSIX Digest::SHA1"

    shepherd_optional_perl_modules = "DateTime::Format::Strptime File::Basename File::Path HTML::Entities \
         HTML::TokeParser HTML::TreeBuilder IO::File Storable Time::HiRes XML::DOM \
         XML::DOM::NodeList XML::Simple Storable HTTP::Cookies File::Basename \
         LWP::ConnCache Digest::MD5 Archive::Zip IO::String \
         DateTime::Format::Strptime \
         HTTP::Cache::Transparent Crypt::SSLeay DBD::mysql "

    perl_modules = shepherd_mandatory_perl_modules.split(" ") + shepherd_optional_perl_modules.split(" ")
    puts "Installing required perl modules...".cyan
    Cpan::install(perl_modules)
  end

  def install_xmltv
    puts "Extracting XMLTV...".cyan
    %x[tar -jxf #{SphinxTv::download_path("xmltv.tar.bz2")} -C #{SphinxTv::cache_path}]
    puts "Compiling XMLTV...".cyan
    commands = Array.new.tap do |c|
      c << "cd #{SphinxTv::cache_path}/xmltv*"
      c << "perl Makefile.PL"
      c << "make"
      c << "make test"
      c << "sudo #{SphinxTv::SUDO_PROMPT} make install"
    end
    puts %x[#{commands.join(";")}]
  end
end