module Mine
	using Sockets
	using SHA
	using JSON
	using Dates
	using HTTP

	username = "Michalpy" #Put here your duino username
	miner_identifier = "Julia PC Miner"
	mining_key = "None" #Put here your mining key

	function log(text::String, color::Union{Symbol,Int}=:normal)
		printstyled("[$(now())] [JULIA-MINER] : $(text)\n"; color = color)
	end	
	function get_pool()
		# Function for getting fastest duino node
		response = HTTP.request(:GET, "https://server.duinocoin.com/getPool", Dict("User-Agent" => "Julia pc miner","Content-Type" => "application/json",))
		response_json = JSON.parse(String(copy(response.body)); dicttype=Dict{Symbol, Any})
		return response_json[:ip], response_json[:port], response_json[:name]
	end
	while true
		try
			# Connecting to duino node
			log("Searching for fastest connection to server")
			ip = "server.duinocoin.com"
			port = 2813
			pool = "default_pool"
			try
				ip, port, pool = get_pool()
			catch e
				log("Using default server port and address", :red)
			end
			socket = connect(ip, port)
			log("Fastest connection found in $(pool)", :yellow)
			server_version = String(read(socket, 3))
			log("Server version: $(server_version)", :yellow)
			# Mining
			while true
				try
					write(socket, "JOB,$(username),LOW,$(mining_key)")
					# Receive work
					job = String(read(socket, 88))
					job = split(job, ",")
					difficulty = job[3]
					hashing_start_time = now()
					for result in range(0, (100 * parse(Int64, difficulty)) + 1)
						# Calculate hash
						string_to_hash = string(job[1], string.(result))
						ducos1 = bytes2hex(sha1(ascii(string_to_hash)))
						# If hash is solved
						if job[2] == ducos1
							# Calculate hashrate
							hashing_stop_time = now()
							timeDifference = datetime2unix(hashing_stop_time) - datetime2unix(hashing_start_time)
							hashrate = result / timeDifference
							# Return result
							write(socket, "$(result),$(hashrate),Julia_PC_Miner,$(miner_identifier)")
							# Check feedback
							feedback = String(read(socket, 5))
							if contains(feedback, "GOOD")
								log(string("Accepted share ",result," Hashrate ", (hashrate/1000.0),"kH/s ","Difficulty ",replace(difficulty, "\n" => "")), :green)
								break
							elseif contains(feedback,"BAD")
								log(string("Rejected share ",result," Hashrate ", (hashrate/1000.0),"kH/s ","Difficulty ",replace(difficulty, "\n" => "")), :red)
								break
							else 
								log("Corrupted feedback ($(feedback))", :red)
								break
							end
						end
					end
				catch e
					println(e)
					log("Error occured, restarting in 3s.", :red)
					sleep(3)
				end
			end
		catch e
			log("Error occured: $(e), restarting in 5s.", :red)
			sleep(5)
		end
	end	
end