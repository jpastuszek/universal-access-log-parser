require 'ip'

class UniversalAccessLogParser
	class ParsingError < RuntimeError
		def initialize(msg, parser, log_line)
			@parser = parser
			@log_line = log_line
			super(msg)
		end

		attr_reader :parser, :log_line
	end

	class ElementGroup < Array
		class Element
			def initialize(name, regexp, nil_on = nil, &parser)
				@name = name
				@regexp = regexp
				@nil_on = nil_on
				@parser = lambda{|s|
					return nil if @nil_on and s == @nil_on
					parser.call(s)
				}
			end

			attr_reader :name, :parser

			def regexp
				return "(#{@nil_on}|#{@regexp})" if @nil_on
				"(#{@regexp})"
			end
		end

		def initialize(separator, surrounded_by = [], &block)
			@separator = separator
			@surrounded_by = surrounded_by.map{|e| Regexp.escape(e)}
			@other = nil
			instance_eval &block
		end

		# getters
		def regexp
			ss = (@surrounded_by[0] or '')
			se = (@surrounded_by[1] or '')

			ss + map{|e| e.regexp}.join(@separator) + se + (@other ? @other : '')
		end
		
		def names
			n = map do |e|
				if e.class == ElementGroup
					e.names
				else
					e.name
				end
			end.flatten
			n << :other if @other
			n
		end

		def parsers
			p = map do |e|
				if e.class == ElementGroup
					e.parsers
				else
					e.parser
				end
			end.flatten
			p << lambda do |s|
				return nil if s.empty?
				s.sub(Regexp.new("^#{@separator}"), '')
			end if @other
			p
		end

		# DSL
		def separated_with(separator, &block)
			push ElementGroup.new(separator, [], &block)
		end

		def surrounded_by(sstart, send, &block)
			push ElementGroup.new(@separator, [sstart, send], &block)
		end

		def element(name, regexp, options = {}, &parser)
			nil_on = options[:nil_on]
			push Element.new(name, regexp, nil_on, &parser)
		end

		def single_quoted(&block)
			surrounded_by("'", "'", &block)
		end

		def double_quoted(&block)
			surrounded_by('"', '"', &block)
		end

		def date_ncsa(name, options = {})
			date(name, '%d/%b/%Y:%H:%M:%S %z', options)
		end

		def date_iis(name, options = {})
			date(name, '%Y-%m-%d %H:%M:%S', options)
		end

		def date(name, format = '%d/%b/%Y:%H:%M:%S %z', options = {})
			regex = Regexp.escape(format).gsub(/%./, '.+').gsub(/\//, '\\/') + '?'
			element(name, regex, options) do |match|
				DateTime.strptime(match, format).new_offset(0).instance_eval do
					Time.utc(year, mon, mday, hour, min, sec + sec_fraction)
				end
			end
		end

		def ip(name, options = {})
			#element(name, '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'){|s| IP.new(s)}
			string(name, options){|s| IP.new(s)}
		end

		def integer(name, options = {})
			element(name, '[\+|-]?\d+', options){|s| s.to_i}
		end

		def float(name, options = {})
			element(name, '[\+|-]?\d+\.?\d*', options){|s| s.to_f}
		end

		def string(name, options = {})
			greedy = true
			greedy = options[:greedy] if options.member? :greedy
			element(name, ".*#{greedy ? '?' : ''}", options) do |s|
				if block_given?
					yield s 
				else
					s
				end
			end
		end

		def other
			@other = "($|#{@separator}.*)"
		end

		def self.parser(name, &block)
			define_method(name, &block)
		end
	end

	class Entry < Struct.new(:name, :parser)
	end

	class ElementParserSet
		def initialize(names, parsers)
			@names = []
			@parsers = {}

			names.zip(parsers).each do |name, parser|
				@names << name
				@parsers[name] = parser
			end
		end

		attr_reader :names, :parsers
	end

	def initialize(&block)
		@@parser_id ||= 0
		@@parser_id += 1

		@elements = ElementGroup.new(' ', &block)
		@elements.other # by default expect more elements

		@regexp = Regexp.new('^' + @elements.regexp + '$')

		@element_parser_set = ElementParserSet.new(@elements.names, @elements.parsers)

		@parsed_log_entry_class = Class.new do
			def self.make_metods(element_parser_set)
				element_parser_set.names.each do |name|
					m = """
						def #{name}
							@element_parser_set.parsers[:#{name}].call(@strings[:#{name}])
						end
					"""
					#puts m
					class_eval m
				end
			end

			def initialize(element_parser_set, strings)
				@strings = {}
				@element_parser_set = element_parser_set

				@element_parser_set.names.zip(strings).each do |name, string|
					@strings[name] = string
				end
			end
		end
		@parsed_log_entry_class.make_metods(@element_parser_set)

	end

	def self.parser(name, &block)
		ElementGroup.parser(name, &block)

		eval """
			def self.#{name}
					self.new{ #{name} }
			end
		"""
	end

	def parse(line)
		matched, *strings = @regexp.match(line).to_a

		raise ParsingError.new('parser regexp did not match log line', self, line) if strings.empty?

		@parsed_log_entry_class.new(@element_parser_set, strings)
	end

	def inspect
		"#<#{self.class.name}:#{@regexp.inspect} => #{@elements.names.join(' ')}>"
	end
end

require 'common_parsers'

