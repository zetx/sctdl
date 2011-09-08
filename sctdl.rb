#!/usr/bin/ruby
# sctdl.rb
# Grabs the ScT RSS DL feed and downloads torrents specified in filter file

require 'net/http'
require 'uri'
require 'config.rb'
require 'open-uri'
require 'rexml/document'

first_run = 1
torrents = Array.new

def get_feed(rssfile, flist, dl_path)
	# Use an array to store each RSS item
	torrents = Array.new
	i = 0

	# Read the filter list into an array
	filter = IO.readlines(flist)

	# Open the RSS file
	rssfeed = open(rssfile)

	# Use the built-in REXML module
	include REXML

	# Read the entire RSS file into memory
	rssdoc = Document.new rssfeed.read
	
	# Extract each RSS item
	rssdoc.elements.each('rss/channel/item') do |item|
		# Read the data from each item
		title = item.elements['title'].text
		category = item.elements['description'].text
		link =	item.elements['link'].text
	
		torrents[i] = "#{category}|#{title}|#{link}"
		i += 1
	end
	
	return torrents
end

def check_passkey(url)
	if $passkey == "00"
		puts "Please update your passkey!"
		exit
	end

	begin
		res = open(url).read
	rescue Errno::EBADF || Timeout::Error
		puts "Timeout Error... retrying in #{$wait_secs} seconds"
		sleep $wait_secs
		check_passkey(url)
	end

	if res.length < 2
		puts "Your passkey is incorrect or the RSS feed is down! Please update it."
		exit
	end

	return 0
end

def parseIt(rss_info)

	filter = IO.readlines($filter_list)
	dl_path = $download_path
	
	for h in 0...rss_info.length	#Loops through entire rss list
		rss_split = rss_info[h].split('|')
		category = rss_split[0]
		title = rss_split[1]#rss_info[i].split('|',2)[1].split('|')[1]
		link = rss_split[2]#rss_info[i].split('|',3)[1].split('|')[2]

		for i in 0...filter.length #Loops through the filter list
			fcat = filter[i].split('|')
			ftitle = filter[i].split('|',2)[1].split('|')
			
			for j in 0...ftitle.length
				if category == fcat[0] && ( title.gsub(/[-_\.]/, ' ') =~ Regexp.new(ftitle[j],1) || ftitle[j] == " " )
					if FileTest.exist? "#{dl_path}#{title}.torrent"
						if $verbose == 1
							puts "EXISTS: #{title}"
						end
					else

						url = URI.parse(link)
						res = Net::HTTP.start(url.host, url.port) {|http|
						http.get(link)
						}
						newFilename = "#{dl_path}#{title}.torrent"
						newFile = File.open(newFilename, "w+")
						newFile.write res.body
						if $verbose == 1
							puts "GET: #{title}"
						end
					end
				end
			end
		end
	end
end

#########MAIN#LOOP#########

while 1
	if first_run == 1 || $always_check == 1
		first_run = check_passkey($sct)
	end

	torrents = get_feed($sct,$filter_list,$download_path)
	parseIt(torrents)
	if $verbose == 1
		puts "Waiting #{$wait_secs} seconds...\n"
	end
	sleep $wait_secs
	system("clear")
end
