class UniversalAccessLogParser
	class ParserBase
	end

	class ElementGroup < Array
		class Element
			def initialize(name, regexp, &parser)
				@name = name
				@regexp = regexp
				@parser = parser
			end

			attr_reader :name, :regexp, :parser
		end

		def initialize(separator, &block)
			@separator = separator
			instance_eval &block
		end

		def separated_with(separator, &block)
			push ElementGroup.new(separator, &block)
		end

		def regexp
			map{|e| e.regexp}.join(@separator)
		end
		
		def names
			names = map do |e|
				if e.class == ElementGroup
					e.names
				else
					e.name
				end
			end.flatten
		end

		def date_ncsa(name)
			date(name, '%d/%b/%Y:%H:%M:%S %z')
		end

		def date_iis(name)
			date(name, '%Y-%m-%d %H:%M:%S')
		end

		def date(name, format = '%d/%b/%Y:%H:%M:%S %z', options = {})
			regex = '(' + Regexp.escape(format).gsub(/%./, '.+').gsub(/\//, '\\/') + ')'
			element(name, regex) do |match|
				DateTime.strptime(match, format).new_offset(0).instance_eval do
					Time.utc(year, mon, mday, hour, min, sec + sec_fraction)
				end.getlocal
			end
		end

		def ip
		end

		def integer
		end

		def float
		end

		def string(name)
			element(name, "(.*)"){|s| s}
		end

		def element(name, regexp, &parser)
			push Element.new(name, regexp, &parser)
		end
	end

	def initialize(&block)
		@elements = ElementGroup.new(' ', &block)

		@parsed_line_class = Struct.new(*@elements.names)
		@regexp = Regexp.new(@elements.regexp)
	end

	def regexp
		@regexp
	end

	def parse(line)
		p self
		full_string, *strings = @regexp.match(line).to_a
		return nil if strings.empty?
		data = []
		@elements.zip(strings).each do |element, string|
			data << element.parser.call(string)
		end
		@parsed_line_class.new(*data)
	end

	def inspect
		"#<#{self.class.name}:#{regexp.inspect}>"
	end
end

