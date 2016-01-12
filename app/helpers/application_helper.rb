require "net/http"
require "uri"

module ApplicationHelper

	# To run locally, set URL, USER, DBNAME, and PASSWORD fields here for REST connectivity
	URL = ""
	DBNAME = ""
	USER = ""
	PASSWORD = ""
	
	# When deploying to Bluemix, controls whether or not to use SSL
	USE_SSL = false

	class City
		attr_accessor :name, :population, :longitude, :latitude, :countryCode

		def initialize(cityName, cityPopulation, cityLatitude, cityLongitude, cityCountryCode)
			@name = cityName
			@population = cityPopulation
			@longitude = cityLongitude
			@latitude = cityLatitude
			@countryCode = cityCountryCode
		end
	    def toJson
	    	return {:name => @name, :population => @population, :latitude => @latitude, :longitude => @longitude, :countryCode => @countryCode}.to_json
	    end
	    def toSql
	    	return "('#{name}', #{population}, #{longitude}, #{latitude}, #{countryCode})"
	    end
	    def toHash
	    	return {:name => @name, :population => @population, :latitude => @latitude, :longitude => @longitude, :countryCode => @countryCode}
	    end
	end

	def code_2xx?(responseCode)
		# response codes in 200's are returned upon success
		# this function should be more robust, but works for this specific use
		if responseCode.start_with?('2')
			return true
		else
			return false
		end
	end 

	def runHelloGalaxy()
		# create array to store info for output
		output = Array.new

		if (URL == nil || URL == "")
			logger.info("parsing VCAP_SERVICES")
			if ENV['VCAP_SERVICES'] == nil
				output.push("Cannot find VCAP_SERVICES in environment")
				return output
			end
                        serviceName = "timeseriesdatabase"
			if ENV['SERVICE_NAME'] != nil
				serviceName = ENV['SERVICE_NAME']
			end
			logger.info("Using service name " + serviceName)
			vcap_hash = JSON.parse(ENV['VCAP_SERVICES'])[serviceName]
			credHash = vcap_hash.first["credentials"]
			dbname = credHash["db"]
			user = credHash["username"]
			password = credHash["password"]
			if (USE_SSL)
				rest_url = credHash["rest_url_ssl"]
			else
				rest_url = credHash["rest_url"]
			end
		else
			rest_url = URL
			dbname = DBNAME
			user = USER
			password = PASSWORD
		end

		collectionName = "rubyRESTGalaxy"
		joinCollectionName = "rubyRESTJoin"
		codeTableName = "codetable"
		cityTableName = "citytable"

		kansasCity = City.new("Kansas City", 467007, 39.0997, 94.5783, 1)
		seattle = City.new("Seattle", 652405, 47.6097, 122.3331, 1);
		newYork = City.new("New York", 8406000, 40.7127, 74.0059, 1);
		london = City.new("London", 8308000, 51.5072, 0.1275, 44);
		tokyo = City.new("Tokyo", 13350000, 35.6833, -139.6833, 81);
		madrid = City.new("Madrid", 3165000, 40.4000, 3.7167, 34);
		melbourne = City.new("Melbourne", 4087000, -37.8136, -144.9631, 61);
		sydney = City.new("Sydney", 4293000, -33.8650, -151.2094, 61)


		uri = URI.parse(rest_url)
		collectionName = "restcollection"
		
		# check if collection exists, if so delete
		http = Net::HTTP.new(uri.host, uri.port)
		request = Net::HTTP::Get.new(uri + "#{dbname}")
		request.basic_auth(user, password)
		response = http.request(request)
		cookie = response['set-cookie'].split('; ')
		output.push("Existing collections: #{response.body}")
		for name in ["#collectionName", "#{joinCollectionName}"]
			if response.body.include? "#{name}"
				output.push("Deleting collection: #{name}")
				request = Net::HTTP::Delete.new(uri + "/#{dbname}/#{name}")
				request['cookie'] = cookie
				response = http.request(request)
				unless code_2xx?(response.code)
					output.push("Failed to delete existing collection")
				end
			end
		end

		# create collection
		output.push("Creating new collections : #{collectionName}, #{joinCollectionName}")
		request = Net::HTTP::Post.new(uri + "/#{dbname}")
		request.content_type = 'application/json'
		request['cookie'] = cookie
		request.body = {:name => "#{collectionName}"}.to_json # use to_json if format not json (e.g. hash)
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to create collection: #{collectionName}")
		end

		request = Net::HTTP::Post.new(uri + "/#{dbname}")
		request['cookie'] = cookie
		request.body = {:name => "#{joinCollectionName}"}.to_json 
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to create collection: #{joinCollectionName}")
		end 

		output.push("")
		output.push("Create tables: #{codeTableName}, #{cityTableName}")
		data = "{name: '#{cityTableName}', options:{columns:[{name:'name', type:'varchar(50)'},"\
			"{name: 'population', type:'int'}, {name: 'longitude', type: 'decimal(8,4)'}, {name: 'latitude', type: 'decimal(8,4)'},"\
			"{name: 'countryCode', type: 'int'}]}}"
		request = Net::HTTP::Post.new(uri + "/#{dbname}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to create relational table: #{cityTableName}")
			output.push("#{response.code}, #{response.body}")
		end
    
		data = "{name: '#{codeTableName}', options:{columns:[{name:'countryCode', type:'int'},"\
		"{name: 'countryName', type: 'varchar(50)'}]}}"
		request = Net::HTTP::Post.new(uri + "/#{dbname}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to create relational table: #{codeTableName}")
			output.push("#{response.code}, #{response.body}")
		end

		output.push("Insert a single document to: #{collectionName}, #{cityTableName}")
		request = Net::HTTP::Post.new(uri + "/#{dbname}/#{collectionName}")
		request['cookie'] = cookie
		request.body = kansasCity.toJson
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to insert single document: #{response.code}, #{response.message}, #{response.body}")
		end
		request = Net::HTTP::Post.new(uri + "/#{dbname}/#{cityTableName}")
		request['cookie'] = cookie
		request.body = kansasCity.toJson
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to insert single document: #{response.code}, #{response.message}, #{response.body}")
		end

		output.push("Insert multiple documents to a collection")
		data = [seattle.toHash, newYork.toHash, london.toHash, tokyo.toHash, madrid.toHash].to_json
		request = Net::HTTP::Post.new(uri + "/#{dbname}/#{collectionName}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to insert multiple documents: #{response.code}, #{response.message}, #{response.body}")
		end

		output.push(" ")
		output.push("Find a document in a collection that matches a query condition")
		queryStr = {:longitude => {"$gt" => 40.0}}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}?query=#{queryStr}&fields={_id:0}&batchSize=1")
		request['cookie'] = cookie
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Query Failed: #{response.code}, #{response.message}, #{response.body}")
		end
		output.push("Result of query: #{response.body}")

		output.push(" ") # only returning two of three documents, missing seattle
		output.push("Find all documents in a collection that match a query condition")
		queryStr = {:longitude => {"$gt" => 40.0}}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}?query=#{queryStr}&fields={_id:0}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Result of query: #{response.body}")
		

		output.push(" ")
		output.push("Find all documents in a collection")
		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("All documents in collection:  #{response.body}")

		output.push("")
		output.push("Count documents in collection") 
		queryStr = {:count => collectionName, :query => {:longitude => {"$lt" => 40.0}}}.to_json
		output.push(queryStr)
		request = Net::HTTP::Get.new(uri + "/#{dbname}/$cmd?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Count: #{response.body}, #{response.code}, #{response.message}")

		output.push("")
		output.push("Order documents in collections: #{collectionName}")
		sortStr = {:population => 1}.to_json
		output.push(sortStr)
		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}/?sort=#{sortStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push(" #{response.body}, #{response.code}, #{response.message}")

		output.push("")
		output.push("Find distinct documents in a collection") # currently not returning result
		queryStr = {:distinct => collectionName, :key => "countryCode", :query => {:longitude => {"$lt" => 40.0}}}.to_json
		output.push(queryStr)
		request = Net::HTTP::Get.new(uri + "/#{dbname}/$cmd?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Count: #{response.body}, #{response.code}, #{response.message}")

		output.push("")
		output.push("Join collection-collection")
		# insert data to codeTable
		data = [{:countryCode => 1, :countryName => 'United States of America'},
			{:countryCode => 44, :countryName => 'United Kingdom'},
			{:countryCode => 81, :countryName => 'Japan'},
			{:countryCode => 34, :countryName => 'Spain'},
			{:countryCode => 61, :countryName => 'Austrailia'}].to_json
		request = Net::HTTP::Post.new(uri + "/#{dbname}/#{codeTableName}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Insert Failed: #{response.code}, #{response.message}, #{response.body}")
		end
		# insert data to joinCollection
		request = Net::HTTP::Post.new(uri + "/#{dbname}/#{joinCollectionName}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Insert Failed: #{response.code}, #{response.message}, #{response.body}")
		end
		query = {:$collections=>{:"#{collectionName}"=>{:$project=>{:name=>1,:population=>1,:longitude=>1,:latitude=>1}},
			:"#{joinCollectionName}"=>{:$project=>{:countryCode=>1,:countryName=>1}}},
			:$condition=>{"#{collectionName}.countryCode"=>"#{joinCollectionName}.countryCode"}}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/system.join?query=#{query}&fields={_id:0,name:1,population:1, countryName:1}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Join results:  #{response.body}")
		unless code_2xx?(response.code)
			output.push("Join Failed: #{response.code}, #{response.message}, #{response.body}")
		end

		output.push("")
		output.push("Join table-collection")
		queryStr = {:$collections => {:"#{collectionName}" => {:$project => {:name => 1, :population => 1, :_id => 0}},
					:codeTable => {:$project => {:countryCode => 1, :countryName => 1}}},
					:$condition => {"#{collectionName}.countryCode" => 'codeTable.countryCode'}}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/system.join?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Join results:  #{response.body}")
		unless code_2xx?(response.code)
			output.push("Join Failed: #{response.code}, #{response.message}, #{response.body}")
		end

		output.push("")
		output.push("Join table-table")
		queryStr = {:$collections => {:cityTable => {:$project => {:name => 1, :longitude => 1, :latitude => 1}},
				:codeTable => {:$project => {:countryCode => 1, :countryName => 1}}},
				:$condition => {'cityTable.countryCode' => 'codeTable.countryCode'}}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/system.join?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Join results:  #{response.body}")
		unless code_2xx?(response.code)
			output.push("Join Failed: #{response.code}, #{response.message}, #{response.body}")
		end

		output.push("")
		output.push("Batch Size")
		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}?batchSize=2")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("#{response.body}")

		output.push("")
		output.push("Find matching documents in a collection with projection")
		queryStr = {:longitude => {"$gt" => 40.0}}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}?query=#{queryStr}&fields={_id:0,name:1,population:1}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("#{response.body}")

		output.push(" ")
		output.push("Update documents in a collection")
		queryStr = {:name => seattle.name}.to_json
		data = {'$set' => {:countryCode => 999}}.to_json
		request = Net::HTTP::Put.new(uri + "/#{dbname}/#{collectionName}?query=#{queryStr}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		output.push("Update result:  #{response.body}")
		unless code_2xx?(response.code)
			output.push("Failed to update value")
		end

		output.push(" ")
		output.push("Delete documents in a collection")
		queryStr = {:name => tokyo.name}.to_json
		request = Net::HTTP::Delete.new(uri + "/#{dbname}/#{collectionName}?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Delete result:  #{response.body}")
		unless code_2xx?(response.code)
			output.push("Failed to delete document")
		end

		output.push("")
		output.push(" SQL Passthrough")
		queryStr = {"$sql" => "create table if not exists town (name varchar(255), countryCode int)"}.to_json
		output.push(queryStr)
		request = Net::HTTP::Get.new(uri + "/#{dbname}/system.sql?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to create table")
			output.push("#{response.body}, #{response.code}, #{response.message}")
		end
		
		queryStr = {"$sql" => "insert into town values ('Lawrence', 1)"}.to_json
		output.push(queryStr)
		request = Net::HTTP::Get.new(uri + "/#{dbname}/system.sql?query=#{queryStr}")
		request['cookie'] = cookie
		request.content_type = 'application/json'
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to insert into table with passthrough")
			output.push("#{response.body}, #{response.code}, #{response.message}")
		end

		queryStr = {"$sql" => "drop table town"}.to_json
		output.push(queryStr)
		request = Net::HTTP::Get.new(uri + "/#{dbname}/system.sql?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to drop table with passthrough")
			output.push("#{response.body}")
		end

		output.push("")
		output.push("Transactions")
		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}?fields={_id:0,name:1}")
		request['cookie'] = cookie
		response = http.request(request)
		if code_2xx?(response.code)
			output.push("Documents in collection before transactions: #{response.body}")
		else
			output.push("Failed to get existing documents in collection")
		end


		queryStr = {:transaction => 'enable'}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/$cmd?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Enabling transactions: #{response.body}, #{response.message}, #{response.code}")
		unless code_2xx?(response.code)
			output.push("Failed to enable transactions")
			output.push("#{response.body}")
		end

		data = melbourne.toJson
		request = Net::HTTP::Post.new(uri + "/#{dbname}/#{collectionName}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to insert melbourne data")
		end

		queryStr = {:transaction => 'commit'}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/$cmd?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Committing insert of Melbourne: #{response.body}, #{response.message}, #{response.code}")
		unless code_2xx?(response.code)
			output.push("Failed to commit")
			output.push("#{response.body}")
		end

		data = sydney.toJson
		request = Net::HTTP::Post.new(uri + "/#{dbname}/#{collectionName}")
		request['cookie'] = cookie
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			output.push("Failed to insert sydney data")
		end

		queryStr = {:transaction => 'rollback'}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/$cmd?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Rolling back insert of Sydney: #{response.body}, #{response.message}, #{response.code}")
		unless code_2xx?(response.code)
			output.push("Failed to rollback")
			output.push("#{response.body}")
		end

		request = Net::HTTP::Get.new(uri + "/#{dbname}/#{collectionName}?fields={_id:0,name:1}")
		request['cookie'] = cookie
		response = http.request(request)
		if code_2xx?(response.code)
			output.push("Documents after rollback: #{response.body}")
		else
			output.push("Failed to get existing documents in collection")
		end

		queryStr = {:transaction => 'disable'}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/$cmd?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		output.push("Disabling transactions: #{response.body}, #{response.message}, #{response.code}")
		unless code_2xx?(response.code)
			output.push("Failed to enable transactions")
			output.push("#{response.body}")
		end
		
		output.push("")
		output.push("Catalog")
		queryStr = {:includeRelational => 'True'}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/?options=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		if code_2xx?(response.code)
			output.push("Collections and relational tables")
			output.push("#{response.body}")
		else
			output.push("Failed to get catalog")
		end

		queryStr = {:includeRelational => 'True', :includeSystem => 'True'}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/?options=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		if code_2xx?(response.code)
			output.push("Collections, relational and system tables")
			output.push("#{response.body}")
		else
			output.push("Failed to get catalog")
		end

		output.push("")
		output.push("Commands")
		queryStr = {:dbstats => 1}.to_json
		request = Net::HTTP::Get.new(uri + "/#{dbname}/$cmd?query=#{queryStr}")
		request['cookie'] = cookie
		response = http.request(request)
		if code_2xx?(response.code)
			output.push("Database stats")
			output.push("#{response.body}")
		else
			output.push("Unable to display database stats")
		end

		output.push("")
		output.push("Delete collections ")
		for name in ["#{collectionName}", "#{joinCollectionName}", "#{cityTableName}", "#{codeTableName}"]
			output.push("Deleting collection: #{name}")
			request = Net::HTTP::Delete.new(uri + "/#{dbname}/#{name}")
			request['cookie'] = cookie
			response = http.request(request)
			unless code_2xx?(response.code)
				output.push("Failed to delete existing collection")
			end
		end

	return output
	end
end
