require 'ip'

class UniversalAccessLogParser
	class ParserError < ArgumentError
	end

	class ParsingError < ArgumentError
		def initialize(msg, parser, line)
			@parser = parser
			@line = line
			super(msg)
		end

		attr_reader :parser, :line
	end

	class ElementParsingError < ArgumentError
		def initialize(e)
			@error = e
			super("argument parsing error: #{e}")
		end

		attr_reader :error
	end

	class ElementGroup < Array
		class Element
			def initialize(name, regexp, nil_on = nil)
				@name = name
				@regexp = regexp
				@nil_on = nil_on
				@parser = lambda{|s|
					return nil if @nil_on and s == @nil_on
					yield s if block_given?
				}
			end

			attr_reader :name, :parser

			def regexp
				return "(#{@nil_on}|#{@regexp})" if @nil_on
				"(#{@regexp})"
			end
		end

		class Integrating < ElementGroup
			def initialize(parent, separator, &block)
				super(parent, &block)
				@separator = separator
			end

			attr_reader :separator
		end

		class Root < Integrating
			def initialize(separator, &block)
				super(nil, separator, &block)
			end

			def regexp
				super + "(|#{separator}.*)"
			end

			def names
				super << :other
			end

			def parsers
				super << lambda{ |s|
					return nil if s.empty?
					s.sub(Regexp.new("^#{separator}"), '')
				}
			end
		end

		class Surrounding < ElementGroup
			def initialize(parent, left, right, &block)
				super(parent, &block)
				@left = left
				@right = right
			end

			def regexp
				@left + super + @right
			end
		end

		class Optional < ElementGroup
			def initialize(parent, name, &block)
				super(parent, &block)
				@group_name = name
			end

			def regexp
				'(|' + super + ')'
			end

			def names
				super.unshift @group_name
			end

			def parsers
				super.unshift lambda{ |s| s.empty? ? nil : s }
			end
		end

		def initialize(parent, &block)
			@parent = parent
			@skip_lines = []
			@other = nil
			instance_eval &block
		end

		# custom parser definition
		def self.parser(name, &block)
			define_method(name, &block)
		end

		# getters
		attr_reader :skip_lines
		
		def separator
			raise ParsingError, 'Integrating ElementGroup not defined in ElementGroup hierarhy' unless @parent
			@parent.separator
		end

		def regexp
			map{|e| e.regexp}.join(separator)
		end
		
		def names
			map do |e|
				if e.kind_of? ElementGroup
					e.names
				else
					e.name
				end
			end.flatten
		end

		def parsers
			map do |e|
				if e.kind_of? ElementGroup
					e.parsers
				else
					e.parser
				end
			end.flatten
		end

		# core DSL
		def integratin_group(separator, &block)
			push ElementGroup::Integrating.new(self, separator, &block)
		end

		def surrounding_group(left, right, &block)
			push ElementGroup::Surrounding.new(self, left, right, &block)
		end

		def optional(name, &block)
			push ElementGroup::Optional.new(self, name, &block)
		end

		def element(name, regexp, options = {}, &parser)
			nil_on = options[:nil_on]
			process = options[:process]
			if process
				p = lambda{|s| process.call(parser.call(s))}
			else
				p = parser 
			end
			push Element.new(name, regexp, nil_on, &p)
		end

		# DSL
		def separated_with(separator, &block)
			integratin_group(separator, &block)
		end

		def surrounded_by(left, right, &block)
			surrounding_group(left, right, &block)
		end

		def skip_line(regexp)
			@skip_lines << regexp
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
			greedy = true
			greedy = options[:greedy] if options.member? :greedy
			element(name, ".*#{greedy ? '?' : ''}", options){|s| IP.new(s)}
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
			element(name, ".*#{greedy ? '?' : ''}", options){|s| s}
		end

		def other
			@other = "($|#{@separator}.*)"
		end
	end

	class EntryIterator
		class Stats < Struct.new(:failures, :successes)
		end

		def initialize(parser, io)
			@parser = parser
			@io = io
		end

		def each
			failures = 0
			successes = 0

			@io.each_line do |line|
				begin
					line.strip!
					next if @parser.skip?(line)
					yield @parser.parse(line.strip)
					successes += 1
				rescue ParsingError
					failures += 1
				end
			end
			Stats.new(failures, successes)
		end

		def each!
			@io.each_line do |line|
				line.strip!
				next if @parser.skip?(line)
				yield  @parser.parse(line.strip)
			end
		end

		def each_parsed!
			@io.each_line do |line|
				line.strip!
				next if @parser.skip?(line)
				yield @parser.parse(line.strip).parse!
			end
		end

		def close
			@io.close
		end
	end

	# just so parsed log line class can be tested and named
	class ParsedLogLine
	end

	def initialize(&block)
		@@parser_id ||= 0
		@@parser_id += 1

		@elements = ElementGroup::Root.new(' ', &block)
		@elements.other # by default expect more elements

		@skip_lines = @elements.skip_lines.map{|s| Regexp.new(s)}
		@regexp = Regexp.new('^' + @elements.regexp + '$')

		@names = @elements.names

		@parsers = {}
		@names.zip(@elements.parsers).each do |name, parser|
			@parsers[name] = parser
		end

		@parsed_log_entry_class = Class.new(ParsedLogLine) do
			def self.name
				superclass.name
			end

			def self.make_metods(names)
				names.each do |name|
					class_eval """
						def #{name}
							return @cache[:#{name}] if @cache.member? :#{name}
							begin
								value = @parsers[:#{name}].call(@strings[:#{name}])
							rescue => e
								raise ElementParsingError.new(e)
							end
							@cache[:#{name}] = value
							value
						end
					"""
				end
			end

			def initialize(names, parsers, strings)
				@parsers = parsers

				@strings = {}
				names.zip(strings).each do |name, string|
					@strings[name] = string
				end

				@cache = {}
			end

			def parse!
				@strings.keys.each do |name|
					send(name)
				end
				self
			end

			def to_hash
				parse!
				@cache
			end

			def inspect
				hash = @cache.dup
				@strings.keys.each do |name|
					hash[name] = '<unparsed>' unless hash.member? name
				end
				"#<#{self.class.name}: #{hash.keys.map{|s| s.to_s}.sort.map{|name| "#{name}: #{hash[name.to_sym].inspect}"}.join(', ')}>"
			end

			def to_s
				"#<#{self.class.name}:#{object_id}>"
			end
		end

		@parsed_log_entry_class.make_metods(@names)
	end

	# custom parser definition
	def self.parser(name, &block)
		ElementGroup.parser(name, &block)

		eval """
			def self.#{name}
					self.new{ #{name} }
			end
		"""
	end

	def skip?(line)
		@skip_lines.each do |regexp|
			return true if line =~ regexp
		end
		return false
	end

	def parse(line)
		matched, *strings = @regexp.match(line).to_a

		raise ParsingError.new('parser regexp did not match log line', self, line) if strings.empty?

		@parsed_log_entry_class.new(@names, @parsers, strings)
	end

	def parse_io(io)
		EntryIterator.new(self, io)
	end

	def parse_file(file_path)
		if block_given?
			File.open(file_path) do |io|
				yield parse_io(io)
			end
		else
			parse_io(File.new(file_path))
		end
	end

	def inspect
		"#<#{self.class.name}:#{@regexp.inspect} => #{@elements.names.join(' ')}>"
	end
end

require 'common_parsers'

