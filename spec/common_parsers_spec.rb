require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'universal-access-log-parser'
require 'time'

describe UniversalAccessLogParser do
	before :all do
		# "%h %l %u %t \"%r\" %>s %b"
		@apache_common = [
			'127.0.0.1 - - [21/Sep/2005:23:06:41 +0100] "GET / HTTP/1.1" 404 -',
			'127.0.0.1 - - [01/Oct/2011:07:29:11 -0400] "GET / " 400 324',
			'127.0.0.1 - - [01/Oct/2011:07:29:11 -0400] "GET /" 400 324',
			'127.0.0.1 - - [01/Oct/2011:07:29:11 -0400] "" 400 324'
		]
		# "%v %h %l %u %t \"%r\" %>s %b"
		@apache_vhost_common = [
			'sigquit.net 127.0.0.1 - - [21/Sep/2005:23:06:41 +0100] "GET / HTTP/1.1" 404 -'
		]
		# "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\""
		@apache_combined = [
			'95.221.65.17 kazuya - [29/Sep/2011:17:38:06 +0100] "GET / HTTP/1.0" 200 1 "http://yandex.ru/yandsearch?text=sigquit.net" "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)"',
			'123.65.150.10 - - [23/Aug/2010:03:50:59 +0000] "POST /wordpress3/wp-admin/admin-ajax.php HTTP/1.1" 200 2 "http://www.example.com/wordpress3/wp-admin/post-new.php" "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_4; en-US) AppleWebKit/534.3 (KHTML, like Gecko) Chrome/6.0.472.25 Safari/534.3"',
			'87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"',
			'80.154.42.54 - - [23/Aug/2010:15:25:35 +0000] "GET /phpmy-admin/scripts/setup.php HTTP/1.1" 404 347 "-" "-"',
			'172.0.0.1 - - [21/Sep/2005:23:06:41 +0100] "GET / HTTP/1.1" 404 - "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b3) Gecko/20050712 Firefox/1.0+"',
			'127.0.0.1 - - [01/Oct/2011:07:51:39 -0400] "GET http://www.test.com/ HTTP/1.1" 200 60662 "-" "test test test"'
		]

		@apache_combined_extra = [
			'127.0.0.1 - - [01/Oct/2011:07:51:39 -0400] "GET http://www.test.com/ HTTP/1.1" 200 60662 "-" "test test test" pass URL-List URL-List 0 - 0'
		]

		# "%{Referer}i -> %U"
		@apache_referer = [
			'http://yandex.ru/yandsearch?text=sigquit.net -> /wordpress3/wp-admin/admin-ajax.php'
		]

		# "%{User-agent}i"
		@apache_user_agent = [
			'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b3) Gecko/20050712 Firefox/1.0+'
		]

		@icecast = [
			'186.16.79.248 - - [02/Apr/2009:14:22:09 -0500] "GET /musicas HTTP/1.1" 200 2497349 "http://www.rol.com.py/wimpy2/rave.swf?cachebust=1238699531218" "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; InfoPath.2)" 592'
		]

		@iis = [
			'2011-06-20 00:00:00 83.222.242.43 GET /SharedControls/getListingThumbs.aspx img=48,13045,27801,25692,35,21568,21477,21477,10,18,46,8&premium=0|1|0|0|0|0|0|0|0|0|0|0&h=100&w=125&pos=175&scale=true 80 - 92.20.10.104 Mozilla/4.0+(compatible;+MSIE+8.0;+Windows+NT+6.1;+Trident/4.0;+GTB6.6;+SLCC2;+.NET+CLR+2.0.50727;+.NET+CLR+3.5.30729;+.NET+CLR+3.0.30729;+Media+Center+PC+6.0;+aff-kingsoft-ciba;+.NET4.0C;+MASN;+AskTbSTC/5.8.0.12304) 200 0 0 609'
		]
	end

	describe 'default parsers' do
		it 'Apache common' do
			parser = UniversalAccessLogParser.apache_common
			data = parser.parse(@apache_common[0])

			data.remote_host.should == IP.new('127.0.0.1')
			data.logname.should == nil
			data.user.should == nil
			data.time.to_i.should == Time.parse('Thu Sep 21 23:06:41 +0100 2005').to_i
			data.method.should == 'GET'
			data.first_request_line.should == 'GET / HTTP/1.1'
			data.uri.should == '/'
			data.protocol.should == 'HTTP/1.1'
			data.status.should == 404
			data.response_size.should == nil

			parser = UniversalAccessLogParser.apache_common
			data = parser.parse(@apache_common[1])

			data.remote_host.should == IP.new('127.0.0.1')
			data.logname.should == nil
			data.user.should == nil
			data.time.to_i.should == Time.parse('Sat Oct 01 13:29:11 +0200 2011').to_i
			data.first_request_line.should == 'GET / '
			data.method.should == 'GET'
			data.uri.should == '/'
			data.protocol.should == nil
			data.status.should == 400
			data.response_size.should == 324

			parser = UniversalAccessLogParser.apache_common
			data = parser.parse(@apache_common[2])

			data.remote_host.should == IP.new('127.0.0.1')
			data.first_request_line.should == 'GET /'
			data.method.should == nil
			data.uri.should == nil
			data.protocol.should == nil
			data.status.should == 400

			parser = UniversalAccessLogParser.apache_common
			data = parser.parse(@apache_common[3])

			data.remote_host.should == IP.new('127.0.0.1')
			data.first_request_line.should == ''
			data.method.should == nil
			data.uri.should == nil
			data.protocol.should == nil
			data.status.should == 400
		end

		it 'Apache vhost common' do
			parser = UniversalAccessLogParser.apache_vhost_common
			data = parser.parse(@apache_vhost_common[0])

			data.vhost.should == 'sigquit.net'
			data.remote_host.should == IP.new('127.0.0.1')
			data.logname.should == nil
			data.user.should == nil
			data.time.to_i.should == Time.parse('Thu Sep 21 23:06:41 +0100 2005').to_i
			data.method.should == 'GET'
			data.uri.should == '/'
			data.protocol.should == 'HTTP/1.1'
			data.status.should == 404
			data.response_size.should == nil
		end

		it 'Apache combined' do
			parser = UniversalAccessLogParser.apache_combined
			data = parser.parse(@apache_combined[0])

			data.remote_host.should == IP.new('95.221.65.17')
			data.logname.should == 'kazuya'
			data.user.should == nil
			data.time.to_i.should == Time.parse('Thu Sep 29 17:38:06 +0100 2011').to_i
			data.method.should == 'GET'
			data.uri.should == '/'
			data.protocol.should == 'HTTP/1.0'
			data.status.should == 200
			data.response_size.should == 1
			data.referer.should == 'http://yandex.ru/yandsearch?text=sigquit.net'
			data.user_agent.should == 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)'
			data.other.should == nil

			parser = UniversalAccessLogParser.apache_combined
			data = parser.parse(@apache_combined[1])

			data.remote_host.should == IP.new('123.65.150.10')
			data.logname.should == nil
			data.user.should == nil
			data.referer.should == 'http://www.example.com/wordpress3/wp-admin/post-new.php'
			data.user_agent.should == 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_4; en-US) AppleWebKit/534.3 (KHTML, like Gecko) Chrome/6.0.472.25 Safari/534.3'

			parser = UniversalAccessLogParser.apache_combined
			data = parser.parse(@apache_combined[2])

			data.remote_host.should == IP.new('87.18.183.252')
			data.referer.should == nil
			data.user_agent.should == 'Feedreader 3.13 (Powered by Newsbrain)'

			parser = UniversalAccessLogParser.apache_combined
			data = parser.parse(@apache_combined[3])

			data.remote_host.should == IP.new('80.154.42.54')
			data.referer.should == nil
			data.user_agent.should == nil

			parser = UniversalAccessLogParser.apache_combined
			data = parser.parse(@apache_combined[4])

			data.remote_host.should == IP.new('172.0.0.1')
			data.logname.should == nil
			data.user.should == nil
			data.time.to_i.should == Time.parse('Thu Sep 21 23:06:41 +0100 2005').to_i
			data.method.should == 'GET'
			data.uri.should == '/'
			data.protocol.should == 'HTTP/1.1'
			data.status.should == 404
			data.response_size.should == nil
			data.referer.should == nil
			data.user_agent.should == 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b3) Gecko/20050712 Firefox/1.0+'

			parser = UniversalAccessLogParser.apache_combined
			data = parser.parse(@apache_combined[5])

			data.remote_host.should == IP.new('127.0.0.1')
			data.logname.should == nil
			data.user.should == nil
			data.method.should == 'GET'
			data.uri.should == 'http://www.test.com/'
			data.protocol.should == 'HTTP/1.1'
			data.status.should == 200
			data.response_size.should == 60662
			data.referer.should == nil
			data.user_agent.should == 'test test test'
		end

		it 'Apache combined file' do
			parser = UniversalAccessLogParser.apache_combined
			entries = []

			parser.parse_file(File.dirname(__FILE__) + '/data/apache_access.log').each_parsed! do |entry|
				entries << entry
			end
			
			entries.should have(178).entries
			entries[3].uri.should == '/robots.txt'
		end

		it 'Apache combined with other data' do
			parser = UniversalAccessLogParser.apache_combined
			data = parser.parse(@apache_combined[0] + ' hello world')

			data.remote_host.should == IP.new('95.221.65.17')
			data.logname.should == 'kazuya'
			data.user.should == nil
			data.time.to_i.should == Time.parse('Thu Sep 29 17:38:06 +0100 2011').to_i
			data.method.should == 'GET'
			data.uri.should == '/'
			data.protocol.should == 'HTTP/1.0'
			data.status.should == 200
			data.response_size.should == 1
			data.referer.should == 'http://yandex.ru/yandsearch?text=sigquit.net'
			data.user_agent.should == 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)'
			data.other.should == 'hello world'
		end

		it 'Apache combined with extra data' do
			parser = UniversalAccessLogParser.new do
				apache_combined
				string :varnish
				string :varnish_status, :nil_on => '-'
				string :initial_varnish_status, :nil_on => '-'
				integer :cache_hits
				integer :cache_ttl, :nil_on => '-'
				integer :cache_age
			end
			data = parser.parse(@apache_combined_extra[0])

			data.remote_host.should == IP.new('127.0.0.1')
			data.logname.should == nil
			data.user.should == nil
			data.method.should == 'GET'
			data.uri.should == 'http://www.test.com/'
			data.protocol.should == 'HTTP/1.1'
			data.status.should == 200
			data.response_size.should == 60662
			data.referer.should == nil
			data.user_agent.should == 'test test test'

			data.varnish.should == 'pass'
			data.varnish_status.should == 'URL-List'
			data.initial_varnish_status.should == 'URL-List'
			data.cache_hits.should == 0
			data.cache_ttl.should == nil
			data.cache_age.should == 0
		end

		it 'Apache referer' do
			parser = UniversalAccessLogParser.apache_referer
			data = parser.parse(@apache_referer[0])

			data.referer.should == 'http://yandex.ru/yandsearch?text=sigquit.net'
			data.url.should == '/wordpress3/wp-admin/admin-ajax.php'
		end

		it 'Apache user agent' do
			parser = UniversalAccessLogParser.apache_user_agent
			data = parser.parse(@apache_user_agent[0])

			data.user_agent.should == 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b3) Gecko/20050712 Firefox/1.0+'
		end

		it 'Icecast' do
			parser = UniversalAccessLogParser.icecast
			data = parser.parse(@icecast[0])

			data.remote_host.should == IP.new('186.16.79.248')
			data.logname.should == nil
			data.user.should == nil
			data.method.should == 'GET'
			data.uri.should == '/musicas'
			data.protocol.should == 'HTTP/1.1'
			data.status.should == 200
			data.response_size.should == 2497349
			data.referer.should == 'http://www.rol.com.py/wimpy2/rave.swf?cachebust=1238699531218'
			data.user_agent.should == 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; InfoPath.2)'
			data.duration.should == 592
		end

		it 'IIS' do
			parser = UniversalAccessLogParser.iis
			data = parser.parse(@iis[0])

			data.time.to_i.should == Time.parse('Mon Jun 20 00:00:00 UTC 2011').to_i
			data.server_ip.should == IP.new('83.222.242.43')
			data.method.should == 'GET'
			data.url.should == '/SharedControls/getListingThumbs.aspx'
			data.query.should == 'img=48,13045,27801,25692,35,21568,21477,21477,10,18,46,8&premium=0|1|0|0|0|0|0|0|0|0|0|0&h=100&w=125&pos=175&scale=true'
			data.port.should == 80
			data.username.should == nil
			data.client_ip.should == IP.new('92.20.10.104')
			data.user_agent.should == 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB6.6; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; aff-kingsoft-ciba; .NET4.0C; MASN; AskTbSTC/5.8.0.12304)'
			data.status.should == 200
			data.substatus.should == 0
			data.win32_status.should == 0
			data.duration.should == 0.609
		end

		it 'IIS log file' do
			entries = []
			parser = UniversalAccessLogParser.iis
			parser.parse_file(File.dirname(__FILE__) + '/data/iis_short.log').each_parsed! do |entry|
				entries << entry
			end
			
			entries.should have(6).entries
			entries[5].url.should == '/blahs/uk/leicestershire/little-bowden/invisalign/index.aspx'
		end
	end
end

