#!/usr/bin/env ruby

require 'fileutils'

if RbConfig::CONFIG["host_os"] =~ /linux/
	$script_location = "./make_site.rb"
	$source_directory = "./sample_site"
	$output_directory = "./sample_output"
elsif RbConfig::CONFIG["host_os"] =~ /wswin|mingw/
	$script_location = "./make_site.rb"
	$source_directory = "./sample_site"
	$output_directory = "./sample_output"
end

puts "Host OS: #{RbConfig::CONFIG['host_os']}"
puts "Script Location: #{$script_location}"
puts "Source Directory: #{$source_directory}"
puts "Output Directory: #{$output_directory}"

system("ruby \"#{$script_location}\" \"#{$source_directory}\" \"#{$output_directory}\"")
