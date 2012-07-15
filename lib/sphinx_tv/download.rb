module Download
  def self.url file_url, filename
    Dir::mkdir("cache") unless FileTest::directory?("cache")

    z_option = (File.exists?(filename) ? " -z #{filename}" : "")
    result = %x[curl -L -w "%{http_code} %{url_effective}"#{z_option} -o #{filename}.download #{file_url}]
    if /304/.match(result)
      puts "Up to date: ".green + filename
      return false
    else
      if /200/.match(result)
        begin
          File.rename "#{filename}.download", filename
        rescue
        end
        puts "Updated: ".yellow + filename
        return true
      else
        File.delete "#{filename}.download" if File.exists? "#{filename}.download"
        puts "File not found: ".red + file_url
        return false
      end
    end
  end

  def self.open_volume(filename, volume_search, &block)
    if File.exists?(filename)
      result = %x[open #{filename}]
      volume = find_mounted_volume volume_search
      if volume.size == 0
        puts "Could not find #{filename} volume".red
      else
        yield volume
      end
    else
      puts "File hasn't been downloaded #{filename}".red
    end
  end

  def self.exists?
    if File.exists?(filename)
      return true
    else
      puts "File hasn't been downloaded #{filename}".red
      return false
    end
  end

  def self.mount(filename, volume_search, &block)
    if File.exists?(filename)
      result = %x[open #{filename}]
      volume = self.find_mounted_volume volume_search
      if volume.size == 0
        puts "Could not find #{filename} volume".red
      else
        yield volume
      end
    else
      yield filename
    end
  end

  def self.find_mounted_volume search
    not_found = true
    retries = 0
    while not_found && retries < 30
      volumes = Dir.glob "/Volumes/#{search}"
      if volumes.size == 0
        retries += 1
        sleep 2
      elsif volumes.size > 1
        puts "Too many similar disk images mounted, please unmount all but latest version".red
        puts "Here are the mounted matching images:"
        volumes.each do |volume|
          puts volume
        end
        return ""
      else
        return volumes[0]
      end
    end
    return ""
  end
end
