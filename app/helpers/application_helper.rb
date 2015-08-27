module ApplicationHelper
=begin 
		parsing of vcap services for bluemix example
		if ENV['VCAP_SERVICES'] == nil
			outPut.push("vcap services is nil")
			return outPut
		end
		vcap_hash = JSON.parse(ENV['VCAP_SERVICES'])["altadb-dev"]
		credHash = vcap_hash.first["credentials"]
		host = credHash["host"]
		port = credHash["json_port"]
		jsonUrl = credHash["json_url"]
		dbname= credHash['db']
		user = credHash["username"]
		password = credHash["password"]
=end
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
		outPut = Array.new
		# connection info for connecting to local server
		host = "bluemix.ibm.com"
		port = "10214"
		dbname = "rubydb"
		user = "informix"
		password = "informix"
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
		http = Net::HTTP.new(host, port) 
		#http = Net::HTTP.new(host, port)
		# clear database by dropping and recreating
		request = Net::HTTP::Delete.new("/#{dbname}")
		request.basic_auth user, password
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to drop #{dbname}")
		end
		request = Net::HTTP::Post.new("/")
		data = {:name => "#{dbname}"}.to_json
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to create #{dbname}")
			outPut.push("#{response.message}, #{response.body}")
		end 
		# create collection
		outPut.push("Creating empty collections : #{collectionName}, #{joinCollectionName}")
		request = Net::HTTP::Post.new("/#{dbname}")
		request.basic_auth user, password
		request.content_type = 'application/json'
		request.body = {:name => "#{collectionName}"}.to_json # use to_json if format not json (e.g. hash)
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to create collection: #{collectionName}")
		end

		request = Net::HTTP::Post.new("/#{dbname}")
		request.basic_auth user, password
		request.body = {:name => "#{joinCollectionName}"}.to_json 
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to create collection: #{joinCollectionName}")
		end 

		outPut.push("")
		outPut.push("Create Tables: #{codeTableName}, #{cityTableName}")
		data = "{name: '#{cityTableName}', options:{columns:[{name:'name', type:'varchar(50)'},"\
			"{name: 'population', type:'int'}, {name: 'longitude', type: 'decimal(8,4)'}, {name: 'latitude', type: 'decimal(8,4)'},"\
			"{name: 'countryCode', type: 'int'}]}}"
		request = Net::HTTP::Post.new("/#{dbname}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to create relational table: #{cityTableName}")
			outPut.push("#{response.code}, #{response.body}")
		end
    
		data = "{name: '#{codeTableName}', options:{columns:[{name:'countryCode', type:'int'},"\
		"{name: 'countryName', type: 'varchar(50)'}]}}"
		request = Net::HTTP::Post.new("/#{dbname}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to create relational table: #{codeTableName}")
			outPut.push("#{response.code}, #{response.body}")
		end

		outPut.push("Insert a single document to: #{collectionName}, #{cityTableName}")
		request = Net::HTTP::Post.new("/#{dbname}/#{collectionName}")
		request.basic_auth user, password
		request.body = kansasCity.toJson
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to insert single document: #{response.code}, #{response.message}, #{response.body}")
		end
		request = Net::HTTP::Post.new("/#{dbname}/#{cityTableName}")
		request.basic_auth user, password
		request.body = kansasCity.toJson
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to insert single document: #{response.code}, #{response.message}, #{response.body}")
		end

		outPut.push("Insert multiple documents to a collection")
		data = [seattle.toHash, newYork.toHash, london.toHash, tokyo.toHash, madrid.toHash].to_json
		request = Net::HTTP::Post.new("/#{dbname}/#{collectionName}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to insert multiple documents: #{response.code}, #{response.message}, #{response.body}")
		end

		outPut.push(" ")
		outPut.push("Find a document in a collection that matches a query condition")
		queryStr = {:longitude => {"$gt" => 40.0}}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}?query=#{queryStr}&fields={_id:0}&batchSize=1")
		request.basic_auth user, password
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Query Failed: #{response.code}, #{response.message}, #{response.body}")
		end
		outPut.push("Result of query: #{response.body}")

		outPut.push(" ") # only returning two of three documents, missing seattle
		outPut.push("Find all documents in a collection that match a query condition")
		queryStr = {:longitude => {"$gt" => 40.0}}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}?query=#{queryStr}&fields={_id:0}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("Result of query: #{response.body}")
		

		outPut.push(" ")
		outPut.push("Find all documents in a collection")
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("All documents in collection:  #{response.body}")

		outPut.push("")
		outPut.push("Count documents in collection") 
		queryStr = {:count => collectionName, :query => {:longitude => {"$lt" => 40.0}}}.to_json
		outPut.push(queryStr)
		request = Net::HTTP::Get.new("/#{dbname}/$cmd?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("Count: #{response.body}, #{response.code}, #{response.message}")

		outPut.push("")
		outPut.push("Order documents in collections: #{collectionName}")
		sortStr = {:population => 1}.to_json
		outPut.push(sortStr)
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}/?sort=#{sortStr}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push(" #{response.body}, #{response.code}, #{response.message}")

		outPut.push("")
		outPut.push("Find distinct documents in a collection") # currently not returning result
		queryStr = {:distinct => collectionName, :key => "countryCode", :query => {:longitude => {"$lt" => 40.0}}}.to_json
		outPut.push(queryStr)
		request = Net::HTTP::Get.new("/#{dbname}/$cmd?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("Count: #{response.body}, #{response.code}, #{response.message}")

		outPut.push("")
		outPut.push("Join collection-collection")
		# insert data to codeTable
		data = [{:countryCode => 1, :countryName => 'United States of America'},
			{:countryCode => 44, :countryName => 'United Kingdom'},
			{:countryCode => 81, :countryName => 'Japan'},
			{:countryCode => 34, :countryName => 'Spain'},
			{:countryCode => 61, :countryName => 'Austrailia'}].to_json
		request = Net::HTTP::Post.new("/#{dbname}/#{codeTableName}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Insert Failed: #{response.code}, #{response.message}, #{response.body}")
		end
		# insert data to joinCollection
		request = Net::HTTP::Post.new("/#{dbname}/#{joinCollectionName}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Insert Failed: #{response.code}, #{response.message}, #{response.body}")
		end
		query = {:$collections=>{:rubyRESTGalaxy=>{:$project=>{:name=>1,:population=>1,:longitude=>1,:latitude=>1}},
			:rubyRESTJoin=>{:$project=>{:countryCode=>1,:countryName=>1}}},
			:$condition=>{'rubyRESTGalaxy.countryCode'=>'rubyRESTJoin.countryCode'}}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/system.join?query=#{query}&fields={_id:0,name:1,countryName:1}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.code}, #{response.body}")

		outPut.push("")
		outPut.push("Join table-collection")
		queryStr = {:$collections => {:rubyRESTGalaxy => {:$project => {:name => 1, :population => 1, :longitude => 1, :latitude => 1}},
					:codeTable => {:$project => {:countryCode => 1, :countryName => 1}}},
					:$condition => {'rubyRESTGalaxy.countryCode' => 'codetable.countryCode'}}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/system.join?query=#{queryStr}&fields={_id:0,name:1,countryname:1}")
		# note that countryname is used instead of countryName in above field.  Since query is from table instead of collection
		# case is not maintained
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.code}, #{response.body}")

		outPut.push("")
		outPut.push("Join table-table")
		queryStr = {:$collections => {:cityTable => {:$project => {:name => 1, :population => 1, :longitude => 1, :latitude => 1}},
				:codeTable => {:$project => {:countryCode => 1, :countryName => 1}}},
				:$condition => {'cityTable.countryCode' => 'codeTable.countryCode'}}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/system.join?query=#{queryStr}&fields={_id:0,name:1,countryname:1}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.code}, #{response.body}")

		outPut.push("")
		outPut.push("Batch Size")
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}?batchSize=2")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.body}")

		outPut.push("")
		outPut.push("Find all documents in a collection with projection")
		queryStr = {:longitude => {"$gt" => 40.0}}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}?query=#{queryStr}&fields={_id:0,name:1,population:1}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.body}")

		outPut.push(" ")
		outPut.push("Update documents in a collection")
		queryStr = {:name => seattle.name}.to_json
		data = {'$set' => {:countryCode => 999}}.to_json
		request = Net::HTTP::Put.new("/#{dbname}/#{collectionName}?query=#{queryStr}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to update value")
		end

		outPut.push(" ")
		outPut.push("Delete documents in a collection")
		queryStr = {:name => tokyo.name}.to_json
		request = Net::HTTP::Delete.new("/#{dbname}/#{collectionName}?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to delete document")
		end
=begin		
		outPut.push("")
		outPut.push(" SQL Passthrough")
		queryStr = {"$sql" => "create table if not exists town (name varchar(255), countryCode int)"}.to_json
		outPut.push(queryStr)
		request = Net::HTTP::Get.new("/#{dbname}/'system.sql'=?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to create table")
			outPut.push("#{response.body}, #{response.code}, #{response.message}")
		end
		
		queryStr = {"$sql" => "insert into town values ('Lawrence', 1)"}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/system.sql?query=#{queryStr}")
		request.basic_auth user, password
		request.content_type = 'application/json'
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to insert into table with passthrough")
			outPut.push("#{response.body}, #{response.code}, #{response.message}")
		end

		queryStr = {"$sql" => "drop table town"}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/system.sql?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to drop table with passthrough")
			outPut.push("#{response.body}")
		end

		outPut.push("")
		outPut.push("Transactions")
		outPut.push("Documents in collection before transactions")
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}?fields={_id:0,name:1}")
		request.basic_auth user, password
		response = http.request(request)
		if code_2xx?(response.code)
			outPut.push("#{response.body}")
		else
			outPut.push("Failed to get existing collections")
		end


		queryStr = {:transaction => 'enable'}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/$cmd?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.body}, #{response.message}, #{response.code}")
		unless code_2xx?(response.code)
			outPut.push("Failed to enable transactions")
			outPut.push("#{response.body}")
		end

		data = melbourne.toJson
		request = Net::HTTP::Post.new("/#{dbname}/#{collectionName}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to insert melbourne data")
		end

		queryStr = {:transaction => 'commit'}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/$cmd?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.body}, #{response.message}, #{response.code}")
		unless code_2xx?(response.code)
			outPut.push("Failed to commit")
			outPut.push("#{response.body}")
		end

		data = sydney.toJson
		request = Net::HTTP::Post.new("/#{dbname}/#{collectionName}")
		request.basic_auth user, password
		request.body = data
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to insert sydney data")
		end

		data = {:transaction => 'rollback'}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/$cmd?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		outPut.push("#{response.body}, #{response.message}")
		unless code_2xx?(response.code)
			outPut.push("Failed to rollback")
			outPut.push("#{response.body}")
		end
		outPut.push("Documents after transactions")
		request = Net::HTTP::Get.new("/#{dbname}/#{collectionName}?fields={_id:0,name:1}")
		request.basic_auth user, password
		response = http.request(request)
		if code_2xx?(response.code)
			outPut.push("#{response.body}")
		else
			outPut.push("Failed to get existing collections")
		end

=end		
		
		outPut.push("")
		outPut.push("Catalog")
		queryStr = {:includeRelational => 'True'}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/?options=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		if code_2xx?(response.code)
			outPut.push("#{response.body}")
		else
			outPut.push("Failed to get catalog")
		end

		outPut.push("")
		queryStr = {:includeRelational => 'True', :includeSystem => 'True'}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/?options=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		if code_2xx?(response.code)
			outPut.push("Relational and system tables")
			outPut.push("#{response.body}")
		else
			outPut.push("Failed to get catalog")
		end

		outPut.push("")
		outPut.push("Commands")
		queryStr = {:dbstats => 1}.to_json
		request = Net::HTTP::Get.new("/#{dbname}/$cmd?query=#{queryStr}")
		request.basic_auth user, password
		response = http.request(request)
		if code_2xx?(response.code)
			outPut.push("Database stats")
			outPut.push("#{response.body}")
		else
			outPut.push("Unable to display database stats")
		end

		outPut.push("")
		outPut.push("Delete a collection")
		request = Net::HTTP::Delete.new("/#{dbname}/#{collectionName}")
		request.basic_auth user, password
		response = http.request(request)
		unless code_2xx?(response.code)
			outPut.push("Failed to delete collection")
		end

	return outPut
	end
end
