require 'Nokogiri'
require 'HTTParty'
require 'csv'
require 'optparse'

BASE_URL = 'https://rubygems.org'

def get_page(path)
  Nokogiri::HTML(HTTParty.get("#{BASE_URL}#{path}"))
end

def get_top_5_gems
  get_page('/stats').css('.stats__graph__gem').map do |gem|
    a = gem.css('.stats__graph__gem__name').at_css('a')
    name = a.text.strip
    path = a['href']
    { name: name, path: path }
  end.first(5)
end

# Return data that contain list of gems' details
def get_data
  get_top_5_gems.map do |gem| 
    page = get_page(gem[:path])
    total_downloads = page.css('.gem__downloads').first.text.delete(',')
    latest_downloads = page.css('.gem__downloads')[1].text.delete(',')
    latest_version = page.at_css('.gem__version-wrap').at_css('a.t-list__item').text
    dependencies = page.at_css('.dependencies').css('a.t-list__item').map do |a|
      a.css('strong').text
    end

    authors = page.at_css('.gem__owners').css('a').map do |a|
      get_page(a['href'])
        .at_css('.profile__header__email')['href']
        .split(':')[1]
    end

    {
      name: gem[:name],
      total_downloads: total_downloads,
      latest_version: latest_version,
      latest_downloads: latest_downloads,
      percentage: (latest_downloads.to_f / total_downloads.to_f * 100).round(2),
      dependencies: dependencies.join(';'),
      authors: authors.join(';')
    }
  end
end

def write_to_csv(filename, data)
  CSV.open(filename, 'w') do |csv|
    csv << %w(name downloads latest_version latest_version_download percentage dependencies authors)
    data.each do |item|
      csv << item.values
    end
  end
end

def main
  options = {}
  OptionParser.new do |opts|
    opts.on('-f', '--filename filename') do |filename|
      options[:filename] = filename
    end
  end.parse!

  puts '-----Start------'
  results = get_data

  puts "Writing to file"
  write_to_csv(options[:filename], results)
  
  puts '-----Finish-----'
end

main
