#! /usr/bin/env ruby
# frozen-string-literal: true

require "csv"
require "json"
require "net/https"
require "uri"

BASE_URL = "https://laws.e-gov.go.jp/api/2"

def fetch_json(url)
  uri = URI(url)
  res = Net::HTTP.get_response(uri)
  #raise "HTTP Error: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)
  res.value # raises if not 200
  JSON.parse(res.body)
end

def get_law_list(offset)
  url = "#{BASE_URL}/laws?law_type=Act&offset=#{offset}&limit=500"
  fetch_json(url)
end

# Enumerator: [abbrev, law_title] を順次 yield
def law_abbrev_enum
  Enumerator.new do |y|
    offset = 0

    loop do
      laws = get_law_list(offset)["laws"]
      break if laws.nil? || laws.empty?

      laws.each do |law|
        law_title = law.dig("revision_info", "law_title")
        abbrev = law.dig("revision_info", "abbrev")

        next unless law_title
        next unless abbrev

        abbrev.split(",", -1).each do |abbr|
          y << [abbr, law_title]
        end
      end

      $stderr.puts "offset #{offset} done (#{laws.size})"
      offset += laws.size
    end
  end
end

if __FILE__ == $0
  output = ARGV.shift
  output ||= "law_abbrev.tsv"
  seen = {}

  CSV.open(output, "w", col_sep: "\t", write_headers: true, headers: "略称\t正式名称") do |tsv|
    enum = law_abbrev_enum
    enum.each do |abbrev, name|
      if seen.key?(abbrev)
        #pp ({ abbrev: abbrev, old: seen[abbrev], new: name, })
        # TODO:
        next
      end

      seen[abbrev] = name
      tsv << [abbrev, name]
    end
  end
end
