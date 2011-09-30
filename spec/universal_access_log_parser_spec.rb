require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'universal_access_log_parser'
require 'time'

describe 'UniversalAccessLogParser' do
	before :all do
		@apache_line = '95.221.65.17 sigquit.net - [29/Sep/2011:17:38:06 +0100] "GET / HTTP/1.0" 200 1 "http://yandex.ru/yandsearch?text=sigquit.net" "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)" "/var/www/localhost/./index.html"'
		@iis_line = '2011-06-20 00:00:00 83.222.242.43 GET /SharedControls/getListingThumbs.aspx img=48,13045,27801,25692,35,21568,21477,21477,10,18,46,8&premium=0|1|0|0|0|0|0|0|0|0|0|0&h=100&w=125&pos=175&scale=true 80 - 92.20.10.104 Mozilla/4.0+(compatible;+MSIE+8.0;+Windows+NT+6.1;+Trident/4.0;+GTB6.6;+SLCC2;+.NET+CLR+2.0.50727;+.NET+CLR+3.5.30729;+.NET+CLR+3.0.30729;+Media+Center+PC+6.0;+aff-kingsoft-ciba;+.NET4.0C;+MASN;+AskTbSTC/5.8.0.12304) 200 0 0 609'
	end

	describe UniversalAccessLogParser::ElementGroup do
		describe 'with nesting' do
			it '#names should return array of all defined element names' do
				e = UniversalAccessLogParser::ElementGroup.new(' ') do
					element :test1, 'test1'
					element :test2, 'test2'
					separated_with ',' do
						element :test3, 'test3'
						element :test4, 'test4'
					end
					element :test5, 'test5'
					element :test6, 'test6'
				end
				e.names.should == [:test1, :test2, :test3, :test4, :test5, :test6]
			end

			it '#regexp should return element regexp joined by separator' do
				e = UniversalAccessLogParser::ElementGroup.new(' ') do
					element :test1, 'test1'
					element :test2, 'test2'
					separated_with ',' do
						element :test3, 'test3'
						element :test4, 'test4'
					end
					element :test5, 'test5'
					element :test6, 'test6'
				end
				e.regexp.should == 'test1 test2 test3,test4 test5 test6'
			end
		end
	end

	describe 'supported type' do
		describe 'string' do
			it 'with space separators' do
				UniversalAccessLogParser.new do
					string :test1
					string :test2
					string :test3
				end.parse('abc def ghi').test2.should == 'def'
			end
		end

		describe 'date' do
			it 'in custom format' do
				p = UniversalAccessLogParser.new do
					string :test1
					date :date, '%d.%b.%Y %H:%M:%S %z'
					string :test2
				end.parse('hello 29.Sep.2011 17:38:06 +0100 world')

				p.date.to_i.should == Time.parse('+Thu Sep 29 17:38:06 +0100 2011').to_i
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end

			it 'in NCSA format' do
				p = UniversalAccessLogParser.new do
					string :test1
					date_ncsa :date
					string :test2
				end.parse('hello 29/Sep/2011:17:38:06 +0100 world')

				p.date.to_i.should == Time.parse('+Thu Sep 29 17:38:06 +0100 2011').to_i
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end

			it 'in IIS format' do
				p = UniversalAccessLogParser.new do
					string :test1
					date_iis :date
					string :test2
				end.parse('hello 2011-06-20 00:00:01 world')

				p.date.to_i.should == Time.parse('Mon Jun 20 00:00:01 +0000 2011').to_i
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end
		end

		describe 'IP' do
			it 'in v4 format' do
				p = UniversalAccessLogParser.new do
					string :test1
					ip :ip
					string :test2
				end.parse('hello 192.168.1.2 world')

				p.ip.should == IP.new("192.168.1.2")
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end

			it 'in v6 format' do
				p = UniversalAccessLogParser.new do
					string :test1
					ip :ip
					string :test2
				end.parse('hello 2001:db8:be00:: world')

				p.ip.should == IP.new("2001:db8:be00::")
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end
		end

		describe 'integer' do
			it 'unsigned' do
				p = UniversalAccessLogParser.new do
					string :test1
					integer :number
					string :test2
				end.parse('hello 1234 world')

				p.number.should == 1234
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end

			it 'signed' do
				p = UniversalAccessLogParser.new do
					string :test1
					integer :number
					string :test2
				end.parse('hello -1234 world')

				p.number.should == -1234
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end
		end
	end

#  it 'can be defined with DSL' do
#		UniversalAccessLogParser.new do
#			date :date
#			ip :server_ip
#			string :method
#			string :url
#			string :query
#			integer :port
#			string :user_aget, {|ua| ua.tr('+', ' ')}
#			string :first_line, :quoted => true
#		end
#  end
end
