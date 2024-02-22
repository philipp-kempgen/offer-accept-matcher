Offer and accept matcher.

Author: Philipp Kempgen, [http://kempgen.net](http://kempgen.net)


## Usage

```ruby
require 'offer_accept_matcher'

offers = [
	{ :main => 'en-UK' , 'q' => 1.0 },
	{ :main => 'de-DE' , 'q' => 0.8 },
]

accept_str = "de-DE;q=1.0, de;q=0.9, en-US;q=0.6, en-UK;q=0.6, en;q=0.5, *;q=0.1"

weighted_offers = OfferAcceptMatcher.compare( accept_str, offers,
	& OfferAcceptMatcher.iso_lang_tag_comparator )

winning_offer = OfferAcceptMatcher.winning_offer( weighted_offers )


puts "Weighted offers:"
weighted_offers.each { |offer|
	puts offer.inspect
}
	#=> [0.9508, {:main=>"de-DE", "q"=>0.8}]
	#=> [0.6010, {:main=>"en-UK", "q"=>1.0}]

puts "Winning offer:"
puts winning_offer[:main].inspect
	#=> "de-DE"

```

