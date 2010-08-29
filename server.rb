#!/usr/bin/ruby
require 'webrick'
require 'stringio'
require 'cgi'
include WEBrick

#######################################
# UploadData - an object to keep track of upload
# data, includes progress hash and file path hash
########################################
class UploadData
	class << self; attr_accessor :progress, :file end
	@progress = Hash.new
	@file = Hash.new
end

########################################
# FileUpload - servlet to handle file upload
# reads data in chunks updating progress, then writes
# file to ./uploads
########################################
class FileUpload < HTTPServlet::AbstractServlet
	def do_POST(request, response)
		# check that we've received file data to upload
		unless request.content_type =~ /^multipart\/form-data; boundary=(.+)/
			raise HTTPStatus::BadRequest
		end
		# uid should be passed in query string
		query = request.query_string
		params = CGI.parse(query)
		uid = params['uid'].to_s
		# set upload progress in hash for given uid
		UploadData.progress[uid] = 0
		# set total length of content to be loaded
		total = request.content_length.to_f
		# set chunk length loaded so far to 0
		sofar = 0
		# keep request chunks as string
		body = String.new
		# load file data by chunks
		request.body do |chunk|
			sofar = sofar + chunk.length.to_f
			progress = ((sofar / total) * 100).to_i
			UploadData.progress[uid] = progress
			body << chunk
		end
		# parse body of request and raise error if file data is empty
		filedata = parse_query(request['content-type'], body)
		raise HTTPStatus::BadRequest if filedata['file'].empty?
		# get the name of the file being uploaded
		filename = get_filename(body)
		# prevent duplicate file names
		while File::exists?('uploads/' + filename)
			parts = filename.split('.')
			parts.insert(parts.length-1, Time.now.to_i.to_s)
			filename = parts.join('.')
		end
		# write file to ./uploads directory
		f = File.new('uploads/' + filename,'wb')
		f.syswrite filedata['file']
		f.close
		# save the path to UploadData.file hash for future use
		UploadData.file[uid] = f.path
		# respond upload complete
		response.status = 200
		response['Content-Type'] = "text/plain"
		response.body = 'upload complete'
	end

	########################################
	# parse_query - takes file content type and body of file reuqest
	# and parses the query using HTTPUtiles:parse_form_data
	########################################
	def parse_query(content_type, body)
		boundary = content_type.match(/^multipart\/form-data; boundary=(.+)/)[1]
		boundary = HTTPUtils::dequote(boundary)
		return HTTPUtils::parse_form_data(body, boundary)
	end

	########################################
	# get_filename - takes body of request and uses a regex
	# to find filename
	########################################
	def get_filename(body)
		filename = 'default_file_name'
		if body =~ /filename="(.*)"/
			filename = $1
		end
		return filename
	end	

end

########################################
# FileUploadProgress - servlet that returns progress of upload
# for file specified by uid param passed in get request, returns
# json object containign data
########################################
class FileUploadProgress < HTTPServlet::AbstractServlet
	def do_GET(request, response)
		# parse query string
		query = request.query_string
		params = CGI.parse(query)
		uid = params['uid'].to_s
		# make sure we have a usable uid
		if uid.empty?
			raise HTTPStatus::BadRequest
		end
		# create progress response json object
		progress = <<-eos
			{
				"progress": "#{UploadData.progress[uid].to_s}"
			}
		eos
		# reset progess if at 100
		if not UploadData.progress[uid].nil? and UploadData.progress[uid] >= 100
			UploadData.progress[uid] = 0
		end
		response.status = 200
		response['Content-Type'] = "text/plain"
		response.body = progress
	end
end

########################################
# FileUploadStatus - servlet that returns absolute and relative 
# paths to file specified by uid as json object in response to
# get request
########################################
class FileUploadStatus < HTTPServlet::AbstractServlet
	def do_GET(request, response)
		# parse query string
		query = request.query_string
		params = CGI.parse(query)
		uid = params['uid'].to_s
		# raise bad request if uid is no good
		if uid.empty?
			raise HTTPStatus::BadRequest
		end
		# json object containing paths to file
		status = <<-eos
			{
				"relative": "#{UploadData.file[uid]}",
				"absolute": "#{File.expand_path(UploadData.file[uid])}"
			}
		eos
		response.status = 200
		response['Content-Type'] = "text/plain"
		response.body = status
	end
end

########################################
# FileUploadTitle - called after file upload, responds to post
# request containing title text and returns title as well as 
# file paths as json object
########################################
class FileUploadTitle < HTTPServlet::AbstractServlet
	def do_POST(request, response)
		# get uid from query
		uid = request.query['uid'].to_s
		# error if no uid povided
		if uid.empty?
			raise HTTPStatus::BadRequest
		end
		title = request.query['title'].to_s
		# provide default title if none entered
		title = 'default title' if title.empty?
		# json object containing title and file paths
		out = <<-eos
			{
				"title": "#{title.to_s}",	
				"relative": "#{UploadData.file[uid]}",
				"absolute": "#{File.expand_path(UploadData.file[uid])}"
			}
		eos
		response.status = 200
		response['Content-Type'] = "text/plain"
		response.body = out
	end
end

# new server, specify port
server = HTTPServer.new(:Port => 8090)

# set rhtml as text/html
HTTPUtils::DefaultMimeTypes.store('rhtml', 'text/html')

# mount servlets to url paths
server.mount "/", HTTPServlet::FileHandler, '/home/soundcloud'
server.mount "/upload", FileUpload
server.mount "/progress", FileUploadProgress
server.mount "/status", FileUploadStatus
server.mount "/title", FileUploadTitle
# kill server on signals
['INT', 'TERM'].each { |signal|
	trap(signal) { server.shutdown }
}
server.start


