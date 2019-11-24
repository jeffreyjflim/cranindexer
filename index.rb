require 'bundler/setup'

require 'open-uri'
require 'fileutils'
require 'tempfile'

require 'dcf'

require 'sequel'


COMMAND_LINE = $0 == 'index.rb' ? true : false


DB_NAME = COMMAND_LINE ? 'prod.db' : 'test.db'
DB = Sequel.connect("sqlite://#{DB_NAME}")
#
Sequel.extension :migration
Sequel::Migrator.run(DB, 'migrations')
#
require './models.rb'


# !! Using a class isn't strictly necessary; but it makes it easier to test with RSpec (you can instantiate an instance and call a method)
class CRANIndexer

	attr_accessor :package_dir

	# !! primarily used for testing
	def clear_db
		[:packages, :authors, :maintainers, :authors_packages].each do |table|
			DB.from(table).truncate
		end
	end

	def handle_http_exceptions(uri, e)
		case e
			when Errno::ECONNREFUSED
				STDERR.puts "Error connecting to #{uri}: check connectivity or try again later"
			when OpenURI::HTTPError
				STDERR.puts "Got OpenURI::HTTPError #{e.io.status} connecting to #{uri}: check connectivity or try again later"
			when ArgumentError
				STDERR.puts "Got ArgumentError: '#{e}' while parsing info for #{uri}: continuing with next package"
			else
				STDERR.puts e.inspect
				STDERR.puts e.backtrace
		end
	end

	def call(packages_path='https://cran.r-project.org/src/contrib/PACKAGES')
		puts "Grabbing package list from #{packages_path}" if COMMAND_LINE
		@package_dir = packages_path.sub(/[^\/]*$/, '')	# !!--> NOTE that /[^\/]*$/ isn't really necessary; we could have stuck with /PACKAGES$/, but this facilitates testing

		package_count = 0
		open(packages_path) do |f|
			lines = ''
			f.each_line {|line|
				if line.strip.empty?
					# do processing
					package_count += 1
					parse lines

					lines = ''
				else
					lines += line if line !~ /^#/
				end

				#break if package_count == 100
			}

			parse lines if lines != ''	# !! the last package may not have an empty line after it!
		end
	rescue StandardError => e
		handle_http_exceptions(packages_path, e)
	end

	private
	def parse(lines)

		FileUtils.mkdir_p('tmp')

		transforms = {
			'Package'          => 'name',
			'Version'          => 'version',
			'Date/Publication' => 'date_publication',
			'Title'            => 'title',
			'Description'      => 'description',
		}

		attribs = (Dcf.parse lines)[0]

		if Package[name: attribs['Package'], version: attribs['Version']]
			puts "skipping duplicate package: #{attribs['Package']}_#{attribs['Version']}" if COMMAND_LINE
			return
		end

		# code from https://stackoverflow.com/questions/2263540/how-do-i-download-a-binary-file-over-http, 'Overbyrd's answer
		download_path = "tmp/#{attribs['Package']}_#{attribs['Version']}.tar.gz"
		package_path = "#{@package_dir}#{attribs['Package']}_#{attribs['Version']}.tar.gz"
		case io = open(package_path)
			when StringIO
				File.open(download_path, 'w') { |f| f.write(io.read) }
			when Tempfile
				io.close
				FileUtils.mv(io.path, download_path)
		end

		desc_string = `tar -Oxf #{download_path} #{attribs['Package']}/DESCRIPTION`
		# !!---DEBUG: `tar -Oxf #{download_path} #{attribs['Package']}/DESCRIPTION > DESCS/#{attribs['Package']}`
		lines += desc_string
		attribs = (Dcf.parse desc_string)[0]
		data_hash = {}
		transforms.each do |transform|
			data_hash[transform[1]] = attribs[transform[0]]
		end

		# parse maintainer name and email
		data_hash['maintainer_name'], maintainer_email = attribs['Maintainer'].split(' <')
		maintainer_email.chop!

		DB[:packages].insert(data_hash)

		# insert maintainer
		begin
			DB[:maintainers].insert(name: data_hash['maintainer_name'], email: maintainer_email)
		rescue Sequel::UniqueConstraintViolation => e
			puts "skipping duplicate maintainer: #{data_hash['maintainer_name']} <#{maintainer_email}>" if COMMAND_LINE
		end
	rescue StandardError => e
		handle_http_exceptions(package_path, e)
	end
end

if COMMAND_LINE
	ARGV[0] ? CRANIndexer.new.call(ARGV[0]) : CRANIndexer.new.call
end
