require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'universal-access-log-parser'
require 'time'

describe 'UniversalAccessLogParser' do
	describe UniversalAccessLogParser::ElementGroup do
		describe 'with nesting' do
			it '#names should return array of all defined element names' do
				e = UniversalAccessLogParser::ElementGroup::Root.new(' ') do
					element :test1, 'test1'
					element :test2, 'test2'
					separated_with ',' do
						element :test3, 'test3'
						element :test4, 'test4'
					end
					element :test5, 'test5'
					element :test6, 'test6'
				end
				e.names.should == [:test1, :test2, :test3, :test4, :test5, :test6, :other]
			end

			it '#regexp should return element regexp joined by separator' do
				e = UniversalAccessLogParser::ElementGroup::Root.new(' ') do
					element :test1, 'test1'
					element :test2, 'test2'
					separated_with ',' do
						element :test3, 'test3'
						element :test4, 'test4'
					end
					element :test5, 'test5'
					element :test6, 'test6'
				end
				e.regexp.should == '(test1) (test2) (test3),(test4) (test5) (test6)(| .*)'
			end

			it '#parser should return array of all element parsers' do
				e = UniversalAccessLogParser::ElementGroup::Root.new(' ') do
					element :test1, 'test1'
					element :test2, 'test2'
					separated_with ',' do
						element :test3, 'test3'
						element :test4, 'test4'
					end
					element :test5, 'test5'
					element :test6, 'test6'
				end
				e.parsers.should have(7).elements
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
					integer :number1
					integer :number2
					string :test2
				end.parse('hello -1234 +1235 world')

				p.number1.should == -1234
				p.number2.should == 1235
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end
		end

		describe 'float' do
			it 'with dot unsigned' do
				p = UniversalAccessLogParser.new do
					string :test1
					float :number
					string :test2
				end.parse('hello 123.4 world')

				p.number.should == 123.4
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end

			it 'whitout dot unsigned' do
				p = UniversalAccessLogParser.new do
					string :test1
					float :number
					string :test2
				end.parse('hello 1234 world')

				p.number.should == 1234.0
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end

			it 'with dot signed' do
				p = UniversalAccessLogParser.new do
					string :test1
					float :number1
					float :number2
					string :test2
				end.parse('hello -123.4 +123.5 world')

				p.number1.should == -123.4
				p.number2.should == 123.5
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end

			it 'whitout dot signed' do
				p = UniversalAccessLogParser.new do
					string :test1
					float :number1
					float :number2
					string :test2
				end.parse('hello -1234 +1235 world')

				p.number1.should == -1234.0
				p.number2.should == 1235.0
				p.test1.should == 'hello'
				p.test2.should == 'world'
			end
		end
	end

	describe 'with quoted/surrounded strings' do
		it 'by []' do
			p = UniversalAccessLogParser.new do
				string :test1
				surrounded_by '\[', '\]' do
					date :date, '%d.%b.%Y %H:%M:%S %z'
				end
				string :test2
			end.parse('hello [29.Sep.2011 17:38:06 +0100] world')

			p.date.to_i.should == Time.parse('+Thu Sep 29 17:38:06 +0100 2011').to_i
			p.test1.should == 'hello'
			p.test2.should == 'world'
		end

		it 'single quoted' do
			p = UniversalAccessLogParser.new do
				string :test1
				single_quoted do
					date :date, '%d.%b.%Y %H:%M:%S %z'
				end
				string :test2
			end.parse("hello '29.Sep.2011 17:38:06 +0100' world")

			p.date.to_i.should == Time.parse('+Thu Sep 29 17:38:06 +0100 2011').to_i
			p.test1.should == 'hello'
			p.test2.should == 'world'
		end

		it 'double quoted' do
			p = UniversalAccessLogParser.new do
				string :test1
				double_quoted do
					date :date, '%d.%b.%Y %H:%M:%S %z'
					integer :number
				end
				string :test2
			end.parse('hello "29.Sep.2011 17:38:06 +0100 123" world')

			p.date.to_i.should == Time.parse('+Thu Sep 29 17:38:06 +0100 2011').to_i
			p.number.should == 123
			p.test1.should == 'hello'
			p.test2.should == 'world'
		end
	end

	describe 'optional blocks' do
		it 'should optionally match set of elements or "" allowing access via name' do
			parser = UniversalAccessLogParser.new do
				string :test1
				optional :first_request_line do
					string :method, :nil_on => ''
					string :uri, :nil_on => ''
					string :protocol, :nil_on => ''
				end
				string :test2
			end

			data = parser.parse('hello GET / HTTP/1.1 world')

			data.first_request_line.should == 'GET / HTTP/1.1'
			data.method.should == 'GET'
			data.uri.should == '/'
			data.protocol.should == 'HTTP/1.1'

			data.test1.should == 'hello'
			data.test2.should == 'world'

			data = parser.parse('hello GET   world')

			data.first_request_line.should == 'GET  '
			data.method.should == 'GET'
			data.uri.should == nil
			data.protocol.should == nil

			data.test1.should == 'hello'
			data.test2.should == 'world'

			data = parser.parse('hello  world')

			data.first_request_line.should == ''
			data.method.should == nil
			data.uri.should == nil
			data.protocol.should == nil

			data.test1.should == 'hello'
			data.test2.should == 'world'
		end	

		it 'should optionally match set of elements or nil allowing access via name if :nil_on option given' do
			parser = UniversalAccessLogParser.new do
				string :test1
				optional :first_request_line, :nil_on => '' do
					string :method, :nil_on => ''
					string :uri, :nil_on => ''
					string :protocol, :nil_on => ''
				end
				string :test2
			end

			data = parser.parse('hello  world')

			data.first_request_line.should == nil
			data.method.should == nil
			data.uri.should == nil
			data.protocol.should == nil

			data.test1.should == 'hello'
			data.test2.should == 'world'
		end
	end

	it 'can parse log with format described in new block' do
		parser = UniversalAccessLogParser.new do
			ip :remote_host
			string :logname, :nil_on => '-'
			string :user, :nil_on => '-'
			surrounded_by '\[', '\]' do
				date_ncsa :time
			end
			double_quoted do
				string :method, :nil_on => ''
				string :uri, :nil_on => ''
				string :protocol, :nil_on => ''
			end
			integer :status
			integer :response_size, :nil_on => '-'
			double_quoted do
				string :referer, :nil_on => '-'
			end
			double_quoted do
				string :user_agent, :nil_on => '-'
			end
		end
		data = parser.parse('95.221.65.17 kazuya - [29/Sep/2011:17:38:06 +0100] "GET / HTTP/1.0" 200 1 "http://yandex.ru/yandsearch?text=sigquit.net" "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)"')

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
	end

	it 'should raise UniversalAccessLogParser::ParsingError on parsing failure' do
		parser = UniversalAccessLogParser.new do
			ip :remote_host
			string :logname, :nil_on => '-'
			string :user, :nil_on => '-'
		end

		lambda {
			parser.parse('123.123.123.213 - -')
		}.should_not raise_error

		lambda {
			parser.parse('123.123.123.213 dasf')
		}.should raise_error UniversalAccessLogParser::ParsingError
	end

	it 'should parse log lines with more elements than defined that then can be accessed via #other' do
		parser = UniversalAccessLogParser.new do
			ip :remote_host
			string :logname, :nil_on => '-'
			string :user, :nil_on => '-'
		end

		data = parser.parse('123.123.123.213 kazuya test a b cdef')
		data.remote_host.should == IP.new('123.123.123.213')
		data.logname.should == 'kazuya'
		data.user.should == 'test'
		data.other.should == 'a b cdef'
	end

	it 'should have nil other if there was no additional data in the log line' do
		parser = UniversalAccessLogParser.new do
			ip :remote_host
			string :logname, :nil_on => '-'
			string :user, :nil_on => '-'
		end

		data = parser.parse('123.123.123.213 kazuya test')
		data.remote_host.should == IP.new('123.123.123.213')
		data.logname.should == 'kazuya'
		data.user.should == 'test'
		data.other.should == nil
	end

	describe 'parsing data sources' do
		before :all do
			@parser = UniversalAccessLogParser.new do
				ip :remote_host
				string :logname, :nil_on => '-'
				string :user, :nil_on => '-'
			end
		end

		it 'IO stream' do
			File.open(File.dirname(__FILE__) + '/data/test1.log') do |io|
				entries = []
				@parser.parse_io(io).each do |entry|
					entries << entry
				end

				entries[0].remote_host.should == IP.new('123.123.123.0')
				entries[1].remote_host.should == IP.new('123.123.123.1')
				entries[2].remote_host.should == IP.new('123.123.123.2')
			end
		end

		it 'should parse file and not leak fd\'s' do
			entries = []

			fds = open_files
			@parser.parse_file(File.dirname(__FILE__) + '/data/test1.log').each do |entry|
				entries << entry
			end
			fds.should == open_files

			entries.should have(3).entries
			entries[0].remote_host.should == IP.new('123.123.123.0')
			entries[1].remote_host.should == IP.new('123.123.123.1')
			entries[2].remote_host.should == IP.new('123.123.123.2')
		end

		it 'should raise IOError if another attempt of each is tried' do
			iter = @parser.parse_file(File.dirname(__FILE__) + '/data/test1.log')
			iter.each do |entry|
			end

			lambda {
				iter.each do |entry|
				end
			}.should raise_error IOError
		end

		it 'should skip lines maching regexp' do
			parser = UniversalAccessLogParser.new do
				skip_line '^#'
				ip :remote_host
				string :logname, :nil_on => '-'
				string :user, :nil_on => '-'
			end

			entries = []
			iter = parser.parse_file(File.dirname(__FILE__) + '/data/test2.log')
			iter.each do |entry|
				entries << entry
			end

			entries.should have(3).entries
			entries[0].remote_host.should == IP.new('123.123.123.0')
			entries[1].remote_host.should == IP.new('123.123.123.1')
			entries[2].remote_host.should == IP.new('123.123.123.2')
		end
	end

	describe 'bad data handling' do
		before :each do
			parser = UniversalAccessLogParser.new do
				ip :remote_host
				string :logname, :nil_on => '-'
				string :user, :nil_on => '-'
			end
			@iter = parser.parse_file(File.dirname(__FILE__) + '/data/bad1.log')
		end

		it 'with each it should not raise exceptions' do
			entries = []
			lambda {
				@iter.each do |entry|
					entries << entry
				end
			}.should_not raise_error

			entries.should have(2).entries
			entries[0].remote_host.should == IP.new('123.123.123.0')
			# line skipped
			entries[1].remote_host.should == IP.new('123.123.123.2')
		end

		it 'with each it should provide parse failure statistics' do
			entries = []
			lambda {
				stats = @iter.each do |entry|
					entries << entry
				end

				stats.failures.should == 1
				stats.successes.should == 2
			}.should_not raise_error

			entries.should have(2).entries
			entries[0].remote_host.should == IP.new('123.123.123.0')
			# line skipped
			entries[1].remote_host.should == IP.new('123.123.123.2')
		end

		it 'with each! it should should raise UniversalAccessLogParser::ParsingError' do
			entries = []
			lambda {
				@iter.each! do |entry|
					entries << entry
				end
			}.should raise_error UniversalAccessLogParser::ParsingError

			entries.should have(1).entries
			entries[0].remote_host.should == IP.new('123.123.123.0')
		end
	end

	describe 'delayed entry parsing' do
		before :each do
			parser = UniversalAccessLogParser.new do
				ip :remote_host
				string :logname, :nil_on => '-'
				string :user, :nil_on => '-'
			end
			@iter = parser.parse_file(File.dirname(__FILE__) + '/data/bad2.log')
		end

		it 'should report errors regarding element parsing on element access' do
			entries = []
			lambda {
				@iter.each do |entry|
					entries << entry
				end
			}.should_not raise_error

			entries.should have(3).entries
			entries[0].remote_host.should == IP.new('123.123.123.0')

			lambda {
				entries[1].remote_host
			}.should raise_error UniversalAccessLogParser::ElementParsingError

			entries[2].remote_host.should == IP.new('123.123.123.2')
		end

		it 'entry #parse! should parse and cache all element values' do
			entries = []
			lambda {
				@iter.each do |entry|
					entries << entry
				end
			}.should_not raise_error

			entries.should have(3).entries

			lambda {
				entries[0].parse!
			}.should_not raise_error

			lambda {
				entries[1].parse!
			}.should raise_error UniversalAccessLogParser::ElementParsingError

			lambda {
				entries[2].parse!
			}.should_not raise_error
		end

		it 'entry #to_hash should return fully parsed hash' do
			entries = []
			lambda {
				@iter.each do |entry|
					entries << entry
				end
			}.should_not raise_error

			entries.should have(3).entries

			h = entries[0].to_hash
			h[:remote_host].should == IP.new('123.123.123.0')
			h[:logname].should == 'hello'
			h[:user].should == 'world'

			lambda {
				entries[1].to_hash
			}.should raise_error UniversalAccessLogParser::ElementParsingError

			h = entries[2].to_hash
			h[:remote_host].should == IP.new('123.123.123.2')
			h[:logname].should == 'hello'
			h[:user].should == nil
		end

		it 'parser #each_parsed! should return fully parsed elements' do
			entries = []
			lambda {
				@iter.each_parsed! do |entry|
					entries << entry
				end
			}.should raise_error UniversalAccessLogParser::ElementParsingError

			entries.should have(1).entries
			entries[0].remote_host.should == IP.new('123.123.123.0')
		end
	end

	it 'should provide nice parsed element inspect output' do
		parser = UniversalAccessLogParser.new do
			ip :remote_host
			string :logname, :nil_on => '-'
			string :user, :nil_on => '-'
		end

		data = parser.parse('123.123.123.213 kazuya test')
		data.remote_host
		data.user
		data.inspect.should == '#<UniversalAccessLogParser::ParsedLogLine: logname: "<unparsed>", other: "<unparsed>", remote_host: #<IP::V4 123.123.123.213>, user: "test">'
	end

	it 'should provide nice parsed element to_s output' do
		parser = UniversalAccessLogParser.new do
			ip :remote_host
			string :logname, :nil_on => '-'
			string :user, :nil_on => '-'
		end

		data = parser.parse('123.123.123.213 kazuya test')
		data.to_s.should =~ /^#<UniversalAccessLogParser::ParsedLogLine/
	end
end

