module OfferAcceptMatcher
	
	Q_KEY = 'q'.freeze
	
	# Parses a comma-separated (",") list of preferences, similar
	# to the Accept, Accept-Charset, Accept-Language and other headers
	# in HTTP.
	# Preferences can be weighted with "q=", see
	# http://tools.ietf.org/html/rfc2616
	# 
	# e.g. "de-DE;q=1, de;q=0.9, en-US;q=0.6, en-UK;q=0.6, en;q=0.5, *;q=0.1"
	# 
	# This isn't a fully valid implementation of a parser for
	# parameters as the are allowed in HTTP headers, as "," (comma)
	# isn't allowed even in quoted string values.
	# 
	# We parse parameters but we don't interpret the main "thing", be
	# it a media type or a character encoding name or an ISO language
	# tag or what have you. It may not include a "," or ";", that's
	# all.
	#
	def self.parse_acceptables_list( str )
		
		acceptables = []
		accept_specs = str.to_s.split(',')
		accept_specs.each { |accept_spec|
			accept_spec_parts = accept_spec.split(';').each( & :'strip!' )
			main = accept_spec_parts.shift || ''
			next if main.empty?
			acceptable = { :main => main, :params => {} }
			accept_spec_parts.each { |param_spec|
				param, value = param_spec.split('=',2)
				next if param.to_s.empty?
				param.strip!
				if value
					# ";param=value"
					value.strip!
					if value.start_with?('"') && value.end_with?('"')
						value = value[ 1, value.length - 2 ]
						value.gsub!( /\\"/, '"' )
					end
					# ";param", e.g. "no-cache"
				end
				acceptable[:params][ param.freeze ] = value
			}
			acceptables << acceptable
		}
		if acceptables.length == 0
			acceptables << { :main => '*'   , :params => {} }
			acceptables << { :main => '*/*' , :params => {} }
		end
		return acceptables
		
	end
	
	def self.interpret_q_values!( acceptables )
		acceptables.each { |acceptable|
			acceptable[:params][Q_KEY] = (acceptable[:params][Q_KEY] || 1.0).to_f
		}
		acceptables
	end
	
	def self.compare( acceptables, offers, &comparator )
		acceptables = parse_acceptables_list( acceptables )  unless acceptables.kind_of?(::Array)
		parse_qvals!( acceptables )
		l = convert_to_lambda( &comparator )
		weighted_offers = offers.map { |offer|
			o = offer.dup
			offer_rating = acceptables.map { |acceptable|
				a = acceptable.dup
				#puts " #{offer.inspect}  #{acceptable.inspect}"
				rating = l.call( o, a )
				if ! rating.respond_to?(:to_f)
					rating = 0.0
				else
					acceptable_q = (acceptable [Q_KEY] || 1.0).to_f
					offer_q      = (offer      [Q_KEY] || 1.0).to_f
					offer_q = 0.5  if ! offer_q.between?( -0.0001, 1.0001 )
					
					rating = rating.to_f * acceptable_q * (offer_q / 4 + (1.0 - 1.0 / 4))
					rating = 0.0 if offer_q == 0.0
					rating+= (offer_q / 1000)
				end
				#puts "    #{offer.inspect}    #{acceptable.inspect}   =>  #{rating}"
				rating
			}.max || 1.0
			[ offer_rating, offer ]
		}
		#weighted_offers.sort_by{ |x| x[0] }.reverse.each { |o|
		#	puts "  #{o.inspect}"
		#}
		
		#winning_offer_rating, winning_offer = weighted_offers.max_by{ |x| x[0] }
		#return winning_offer
		weighted_offers.sort_by!{ |x| x[0] }.reverse!
		return weighted_offers
	end
	
	def self.winning_offer( sorted_weighted_offers )
		#winning_offer = (unsorted_weighted_offers || []).max_by{ |x| x[0] }
		winning_offer = (sorted_weighted_offers || []).first
		return (winning_offer || [])[1]  # can be nil
	end
	
	def self.simplistic_comparator
		return lambda { |offer, acceptable|
			o_main = offer      [:main].to_s.downcase
			a_main = acceptable [:main].to_s.downcase
			return 1.00 if o_main == a_main
			return 0.90 if a_main == '*'
			return 0.90 if a_main == '*/*'
			return 0.40 if o_main.start_with?( a_main )
			return 0.30 if a_main.start_with?( o_main )
			return 0.01
		}
	end
	
	def self.charset_comparator
		return lambda { |offer, acceptable|
			o_main = offer      [:main].to_s.downcase
			a_main = acceptable [:main].to_s.downcase
			return 1.00 if o_main == a_main
			return 0.90 if a_main == '*'
			return 0.01
		}
	end
	
	# http://tools.ietf.org/html/rfc2616#section-14.4
	# http://tools.ietf.org/html/rfc2616#section-3.10
	#
	def self.iso_lang_tag_comparator
		return lambda { |offer, acceptable|
		#return ->( offer, acceptable ) {  # stabby lamdas! :-)
			o_lang = offer      [:main].to_s.downcase.gsub('_','-')
			a_lang = acceptable [:main].to_s.downcase.gsub('_','-')
			return 1.00 if o_lang == a_lang
			return 0.99 if a_lang == '*'
			o_lang_parts = o_lang.split('-')
			a_lang_parts = a_lang.split('-')
			common_len = [ o_lang_parts, a_lang_parts ].map(& :length).min
			common_len = [ common_len, 20 ].min  # max. size
			while common_len > 0
				if o_lang_parts.first( common_len ) == a_lang_parts.first( common_len )
					return 0.6 +
						(0.005 * common_len) +
						(o_lang_parts.length > a_lang_parts.length ? 0.002 : -0.002)
				end
				common_len -= 1
			end
			return 0.00
		}
	end
	
	#def self.mime_type_comparator
	#end
	
	private
	
	def self.parse_qvals!( acceptables )
		acceptables.each { |acceptable|
			qf = 1.0
			qv = acceptable[:params][Q_KEY]
			if qv
				qv.match( /\A\s* (?<qs> [01](\.\d{0,3})? )/x ) { |m|
					qf = m[:qs].to_f
				}
			end
			acceptable[Q_KEY] = qf
		}
		return nil
	end
	
	def self.convert_to_lambda( &block )
		return block if block.lambda?
		obj = ::Object.new
		obj.define_singleton_method( :_, &block )
		return obj.method(:_).to_proc
	end
	
end

