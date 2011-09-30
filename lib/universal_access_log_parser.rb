require 'ip'

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

		def initialize(separator, surrounded_by = [], &block)
			@separator = separator
			@surrounded_by = surrounded_by.map{|e| Regexp.escape(e)}
			instance_eval &block
		end

		# getters
		def regexp
			ss = (@surrounded_by[0] or '')
			se = (@surrounded_by[1] or '')

			ss + map{|e| e.regexp}.join(@separator) + se
		end
		
		def names
			map do |e|
				if e.class == ElementGroup
					e.names
				else
					e.name
				end
			end.flatten
		end

		def parsers
			map do |e|
				if e.class == ElementGroup
					e.parsers
				else
					e
				end
			end.flatten
		end

		# DSL
		def separated_with(separator, &block)
			push ElementGroup.new(separator, [], &block)
		end

		def surrounded_by(sstart, send, &block)
			push ElementGroup.new(@separator, [sstart, send], &block)
		end

		def element(name, regexp, &parser)
			push Element.new(name, regexp, &parser)
		end

		def single_quoted(&block)
			surrounded_by("'", "'", &block)
		end

		def double_quoted(&block)
			surrounded_by('"', '"', &block)
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

		def ip(name)
			#element(name, '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'){|s| IP.new(s)}
			string(name){|s| IP.new(s)}
		end

		def integer(name)
			element(name, '([\+|-]?\d+)'){|s| s.to_i}
		end

		def float(name)
			element(name, '([\+|-]?\d+\.?\d*)'){|s| s.to_f}
		end

		def string(name)
			element(name, "(.*)") do |s|
				if block_given?
					yield s 
				else
					s
				end
			end
		end
	end


	def initialize(&block)
		@@parser_id ||= 0
		@@parser_id += 1

		@elements = ElementGroup.new(' ', &block)

		@parsed_log_entry_class = Struct.new("ParsedLogEntry#{@@parser_id}", *@elements.names)
		@regexp = Regexp.new(@elements.regexp)
	end

	def parse(line)
		matched, *strings = @regexp.match(line).to_a

		return nil if strings.empty?

		data = @elements.parsers.zip(strings).map do |element, string|
			element.parser.call(string)
		end

		@parsed_log_entry_class.new(*data)
	end

	def inspect
		"#<#{self.class.name}:#{@regexp.inspect} => #{@elements.names.join(' ')}>"
	end
end

