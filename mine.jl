module Mine
	using Sockets
	using SHA
	using JSON
	using Dates
	using HTTP
	function get_pool()
		response = HTTP.request(
						:GET, 
						"https://server.duinocoin.com/getPool", 
						Dict(
							"User-Agent" => "Julia pc miner",
							"Content-Type" => "application/json",
						)
					)
		response_json = JSON.parse(String(copy(response.body)); dicttype=Dict{Symbol, Any})
		return response_json[:ip], response_json[:port], response_json[:name]
	end

	username = "Michalpy"
	function run()
		ip, port, pool = get_pool()
		socket = Sockets.connect(ip, port)
		println("Connected to $(pool)")
		server_ver = String(read(socket, 3))
		println("Server is on version: ", server_ver)
		while true
			try
				write(socket, string("JOB,", String(username), ",Julia PC miner"))
				println("Looking for job...")
				job = String(read(socket, 87))
				job = split(job, ",")
				if length(job) <= 2 continue end
				println(job)
				lastBlockHash = job[1]
				result = job[2]
				difficulty = parse(Int32, job[3]) * 100
				hashing_start_time = now()
				for i = 0 : (100 * difficulty + 1)
					stringToHash = string(lastBlockHash, string.(i-1))
					ducos1 = bytes2hex(sha1(stringToHash))
					if ducos1 == result
						hashing_stop_time = now()
						timeDifference = datetime2unix(hashing_stop_time) - datetime2unix(hashing_start_time)
						hashrate = i / timeDifference
						write(socket, string(i, ",,Julia_Miner"))
						feedback = String(read(socket, 4))
						println(feedback)
						if contains(feedback, "00")
							println("Accepted share ", i, "\tDifficulty ", difficulty)
							break
						else
							println("Rejected share ", i, "\tDifficulty ", difficulty)
							break
						end
					end
					i += 1
				end
			catch e
				println("Error to $(e)")
				break
			 end
		end
	end
	run()
end