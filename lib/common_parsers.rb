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
	string :user_agent, :nil_on => '-'
end

