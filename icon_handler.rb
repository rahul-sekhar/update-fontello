require 'fileutils'
require 'pathname'

class IconHandler
  def self.update(icons_path, options = {})
    IconUpdater.run(icons_path, options)
  end

  class Runner
    def self.run(*args)
      new(*args).run
    end

    def info(message)
      puts "\n** #{message} **"
    end
  end

  class IconUpdater < Runner
    def initialize(icons_path, options = {})
      @path = Pathname.new(icons_path)

      if options[:css]
        @css_file = Pathname.new(options[:css])
      else
        raise "Please pass a filename for the css option"
      end

      if options[:ie_css]
        @ie_css_file = Pathname.new(options[:ie_css])
      end
    end

    def run
      return if !check_zip
      extract_zip

      begin
        update_fonts
        update_config
        update_css
        remove_zip
      ensure
        remove_dir
      end
    end

    private

    def remove_zip
      info "Removing zip file"
      FileUtils.rm zip_file
    end

    def remove_dir
      if File.directory? font_folder
        info "Removing directory"
        FileUtils.rm_rf font_folder
      end
    end

    def update_css
      if File.file? @css_file
        info "Updating css file: #{@css_file}"
        update_css_querystring
        update_css_codes
      else
        info "Creating css file: #{@css_file}"
        create_css
      end

      if @ie_css_file
        if File.file? @ie_css_file
          info "Updating css file: #{@ie_css_file}"
          update_ie_css_codes
        else
          info "Creating IE css file: #{@ie_css_file}"
          create_ie_css
        end
      end
    end

    def update_ie_css_codes
      css_content = File.open(@ie_css_file).read
      code_start_pos = css_content.index /.icon-[\w-]+ ?{ ?\*zoom:/
      raise "Font icon codes not found in file: #{@ie_css_file}" if !code_start_pos
      # Remove old codes
      css_content = css_content[0..(code_start_pos - 2)]
      # Add new ones
      css_content += File.open(font_folder.join 'css', 'fontello-ie7-codes.css').read
      # Update file
      File.open(@ie_css_file, 'w') { |f| f.write(css_content) }
    end

    def update_css_codes
      css_content = File.open(@css_file).read
      code_start_pos = css_content.index /.icon-[\w-]+:before ?{ ?content:/
      raise "Font icon codes not found in file: #{@css_file}" if !code_start_pos
      # Remove old codes
      css_content = css_content[0..(code_start_pos - 2)]
      # Add new ones
      css_content += File.open(font_folder.join 'css', 'fontello-codes.css').read
      # Update file
      File.open(@css_file, 'w') { |f| f.write(css_content) }
    end

    def update_css_querystring
      old_querystring = get_querystring @css_file
      if old_querystring
        new_querystring = get_querystring font_folder.join 'css', 'fontello.css'
        replace_querystring(@css_file, old_querystring, new_querystring)
      else
        info "Not replacing querystring"
      end
    end

    def replace_querystring(css_file, oldq, newq)
      css_content = File.open(css_file).read
      css_content.gsub! oldq, newq
      File.open(css_file, 'w') { |f| f.write(css_content) }
    end

    def get_querystring(css_file)
      css_content = File.open(css_file).read
      matches = css_content.scan /fontello.(?:eot|woff|ttf|svg)\?(\d+)/

      if matches.empty?
        info "No querystring found in file: #{css_file}"
        return false
      end
      raise "Non-unique querystring found in file: #{css_file}" if matches.uniq.length > 1

      matches.flatten.first
    end

    def create_ie_css
      FileUtils.cp font_folder.join('css', 'fontello-ie7.css'), @ie_css_file, verbose: true
    end

    def create_css
      FileUtils.cp font_folder.join('css', 'fontello.css'), @css_file, verbose: true
    end

    def update_config
      info "Updating config.json"
      FileUtils.cp font_folder.join('config.json'), @path, verbose: true
    end

    def update_fonts
      info "Updating fonts"
      FileUtils.cp Dir.glob(font_folder.join 'font', '*'), @path, verbose: true
    end

    def extract_zip
      system "unzip #{zip_file} -d #{@path}"
    end

    def check_zip
      if zip_file
        info "Updating from zip file: #{zip_file.basename}"
        return true
      end

      info "No fontello zip files found in #{@path}"
      return false
    end

    def font_folder
      zip_file.dirname.join zip_file.basename('.*')
    end

    def zip_file
      zip_path = Dir.glob("#{@path}/fontello-*.zip").first
      @zip_file ||= zip_path ? Pathname.new(zip_path) : nil
    end
  end
end