UniversalAccessLogParser.parser(:apache_common) do
	ip :remote_host
	string :logname, :nil_on => '-'
	string :user, :nil_on => '-'
	surrounded_by '[', ']' do
		date_ncsa :time
	end
	double_quoted do
		string :method, :nil_on => ''
		string :uri, :nil_on => ''
		string :protocol, :nil_on => ''
	end
	integer :status
	integer :response_size, :nil_on => '-'
end

UniversalAccessLogParser.parser(:apache_vhost_common) do
	string :vhost
	apache_common
end

UniversalAccessLogParser.parser(:apache_combined) do
	apache_common
	double_quoted do
		string :referer, :nil_on => '-'
	end
	double_quoted do
		string :user_agent, :nil_on => '-'
	end
end

UniversalAccessLogParser.parser(:apache_referer) do
	separated_with ' -> ' do
		string :referer, :nil_on => '-'
		string :url
	end
end

UniversalAccessLogParser.parser(:apache_user_agent) do
	string :user_agent, :nil_on => '-', :greedy => false
end

UniversalAccessLogParser.parser(:icecast) do
	apache_combined
	integer :duration, :nil_on => '-'
end

UniversalAccessLogParser.parser(:iis) do
	date_iis :time
	ip :server_ip
	string :method
	string :url
	string :query, :nil_on => '-'
	integer :port
	string :username, :nil_on => '-'
	ip :client_ip
	string :user_agent, :nil_on => '-', :process => lambda{|s| s.tr('+', ' ')}
	integer :status
	integer :substatus
	integer :win32_status
	integer :duration, :process => lambda{|i| i.to_f / 1000}
end

