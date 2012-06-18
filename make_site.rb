#!/usr/bin/env ruby
# encoding: UTF-8

require 'rubygems'
require 'haml'
require 'sass'

require 'pathname'
require 'json'
require 'rss'

if RbConfig::CONFIG["host_os"] =~ /linux/
	$OS = :linux
elsif RbConfig::CONFIG["host_os"] =~ /wswin|mingw/
	$OS = :windows
else
	$OS = :unknown
end

$comic_width = 600
$thumb_width = 100

$valid_comic_extensions = [".png",".jpg",".gif"]

$default_comic_data = {
	"context" => [],
	"timestamp" => "2012-01-01 00:00:00"
}

def make_pathname(string)
	begin
		pathname = Pathname.new(string).realpath
	rescue
		puts "Exception while parsing pathname!"
		puts "I can't resolve: #{string}"
		exit
	end
end

if ARGV.length != 2
	puts "Usage: make_frontpage.rb site_directory output_directory"
	exit
end

site_directory = make_pathname(ARGV[0])
output_directory = make_pathname(ARGV[1])

config_path = site_directory + "config.json"
styles_path = site_directory + "styles.sass"
template_path = site_directory + "template.haml"

comic_directory = site_directory + "comics"
news_directory = site_directory + "news"
overlay_directory = site_directory + "overlay"

[	config_path,
	styles_path,
	template_path,
	comic_directory,
	news_directory,
	overlay_directory
].each do |path|
	unless path.exist?
		puts "Cannot find #{path}"
		exit
	end
end

styles_sass = Sass::Engine.new(styles_path.read, :syntax => :sass)
template_haml = Haml::Engine.new(template_path.read)

styles_output_path = output_directory + "styles.css"
index_output_path = output_directory + "index.html"
atom_output_path = output_directory + "index.atom"
rss_output_path = output_directory + "index.rss"
archive_output_path = output_directory + "archive.html"

$config = JSON::load(config_path)

# Common Functions
def path_to_title(path)
	title = path.basename.sub_ext("").to_s
	title.gsub("_"," ")
end

module Names
	def Names::comic_to_html(pathname)
		Pathname.new(pathname).basename.sub_ext(".html")
	end

	def Names::comic_to_crushed(pathname)
		Pathname.new(pathname).basename.sub_ext("_crushed.png")
	end

	def Names::comic_to_scaled(pathname)
		Pathname.new(pathname).basename.sub_ext("_scaled.png")
	end

	def Names::comic_to_thumb(pathname)
		Pathname.new(pathname).basename.sub_ext("_thumb.png")
	end
end

# Frontpage Functions
def recent_comics
	lines = []
	$comic_list[-5..-1].each do |comic|
		lines.push "<a href='#{Names::comic_to_html(comic)}'><img src='#{Names::comic_to_thumb(comic)}'></a>"
	end
	lines.join
end

def recent_news
	lines = []
	$news_list[-5..-1].reverse_each do |news|
		data = $news_data[news]
		if data.include? "text"
			lines.push "<div class='standard boxed blurb'>"

			if data.include? "icon"
				lines.push "<img class='icon' src='#{data["icon"]}'/>"
			end

			lines.push "<div class='text'>#{data["text"]}</div>"

			if data.include? "timestamp"
				lines.push "<div class='understatement'>"
				lines.push "(Posted <abbr class='timeago' title='#{data["timestamp"]}'>#{data["timestamp"]}</abbr>)"
				lines.push "</div>"
			end

			lines.push "</div>"
		end
	end
	lines.join
end

## Comic Functions
def comic_image
	Names::comic_to_scaled($comic_list[$current_comic_index]).basename
end

def comic_title
	$comic_data[$comic_list[$current_comic_index]]["title"]
end

def first_comic
	Names::comic_to_html($comic_list[0]).basename
end

def next_comic
	Names::comic_to_html($comic_list[[$current_comic_index + 1, $comic_list.length - 1].min]).basename
end

def previous_comic
	Names::comic_to_html($comic_list[[$current_comic_index - 1, 0].max]).basename
end

def newest_comic
	Names::comic_to_html($comic_list[-1]).basename
end

def comment_topic
	Pathname.new($comic_list[$current_comic_index]).basename
end

## Archive Functions
def comic_list
	lines = []
	prev_context = []
	lines.push "<ul>"
	$comic_list.each do |comic|
		current_context = $comic_data[comic]["context"]

		while prev_context.length > current_context.length
			lines.push "</ul></li>"
			prev_context.pop
		end

		index = 0
		while index < current_context.length \
		and prev_context[index] == current_context[index]
			index += 1
		end

		while index < prev_context.length
			lines.push "</ul></li>"
			prev_context.pop
		end

		while index < current_context.length
			prev_context.push current_context[index]
			lines.push "<li>#{current_context[index]}<ul>"
			index += 1
		end

		lines.push "<li><a href='#{Names::comic_to_html(comic).basename}'>#{$comic_data[comic]["title"]}</a></li>"
	end
	lines.join
end

## Read Comic Data
unchecked_dirs = [comic_directory]
$comic_list = []

while unchecked_dirs.length > 0
	dir = unchecked_dirs.shift
	dir.each_child do |child|
		if child.directory?
			unchecked_dirs.push child
		else
			$comic_list.push child
		end
	end
end

$comic_list.keep_if do |path|
	$valid_comic_extensions.include? path.extname
end

$comic_list.sort!

$comic_data = {}

$comic_list.each do |path|
	metadata_path = path.sub_ext(".json")
	$comic_data[path] = $default_comic_data.dup
	if metadata_path.readable?
		$comic_data[path].update(JSON::load(metadata_path))
	else
		$comic_data[path].update({"title" => path_to_title(path)})
	end
end

## Read News Data
unchecked_dirs = [news_directory]
$news_list = []

while unchecked_dirs.length > 0
	dir = unchecked_dirs.shift
	dir.each_child do |child|
		if child.directory?
			unchecked_dirs.push child
		else
			$news_list.push child
		end
	end
end

$news_list.keep_if do |path|
	path.extname == ".json"
end

$news_list.sort!

$news_data = {}

$news_list.each do |path|
	if path.readable?
		$news_data[path] = JSON::load(path)
	end
end

## Write styles
styles_output_path.open("w") do |file|
	file.write styles_sass.to_css
end

## Write frontpage
$page_type = :front
index_output_path.open("w") do |file|
	file.write template_haml.render
end

## Write archive page
$page_type = :archive
archive_output_path.open("w") do |file|
	file.write template_haml.render
end

## Write comic pages
$page_type = :comic
$current_comic_index = 0
while $current_comic_index < $comic_list.length
	comic_output_path = output_directory + Names::comic_to_html($comic_list[$current_comic_index]).basename

	comic_output_path.open("w") do |file|
		file.write template_haml.render
	end

	$current_comic_index += 1
end

## Convert comic files
if $OS == :linux
	convert_command = "convert"
	optipng_command = "optipng"
elsif $OS == :windows
	convert_command = "./convert.exe"
	optipng_command = "./optipng.exe"
end

$comic_data.each do |comic, data|
	comic = Pathname.new(comic)

	scaled_path = output_directory + (Names::comic_to_scaled(comic).basename)
	thumb_path = output_directory + (Names::comic_to_thumb(comic).basename)

	if not scaled_path.exist? or scaled_path.mtime < comic.mtime
		system("#{convert_command} \"#{comic}\" -filter Catrom -resize #{$comic_width}x -strip \"#{scaled_path}\"")
		system("#{optipng_command} \"#{scaled_path}\"")
	end

	if not thumb_path.exist? or thumb_path.mtime < comic.mtime
		system("#{convert_command} \"#{comic}\" -filter Catrom -resize #{$thumb_width}x -strip \"#{thumb_path}\"")
		system("#{optipng_command} \"#{thumb_path}\"")
	end
end

## Write Atom and RSS Feeds
atom = RSS::Maker.make("atom") do |maker|
	maker.channel.title = $config["rss_title"]
	maker.channel.about = $config["rss_url"]
	maker.channel.author = $config["rss_author"]
	maker.channel.updated = Time.now.to_s

	$comic_list.each do |comic|
		maker.items.new_item do |item|
			item.link = $config["rss_url"] + Names::comic_to_html(comic).to_s
			item.title = $comic_data[comic]["title"]
			item.updated = $comic_data[comic]["timestamp"]
		end
	end
end

atom_output_path.open("w"){ |file|
	file.write atom.to_s
}

rss = RSS::Maker.make("2.0") do |maker|
	maker.channel.title = $config["rss_title"]
	maker.channel.link = $config["rss_url"]
	maker.channel.description = $config["rss_title"]
	maker.channel.author = $config["rss_author"]
	maker.channel.date = Time.now.to_s

	$comic_list.each{ |comic|
		maker.items.new_item { |item|
			item.link = $config["rss_url"] + Names::comic_to_html(comic).to_s
			item.title = $comic_data[comic]["title"]
			item.date = $comic_data[comic]["timestamp"]
		}
	}
end

rss_output_path.open("w"){ |file|
	file.write rss.to_s
}

## Copy Overlay
Dir.chdir(overlay_directory)
files = Dir.glob("*")
FileUtils.cp_r(files, output_directory)

puts "make_site.rb completed without errors."
