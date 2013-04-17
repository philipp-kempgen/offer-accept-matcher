# -*- encoding: utf-8 -*-

lib_dir = File.expand_path( '../lib/', __FILE__ )
$LOAD_PATH.unshift( lib_dir )

#require 'offer_accept_matcher/version'

spec = Gem::Specification.new { |s|
	s.name         = 'offer_accept_matcher'
	s.version      = '0.0.2'
	s.summary      = "Offer and accept matcher."
	s.description  = "Matches offers and \"acceptables\"."
	s.author       = "Philipp Kempgen"
	s.homepage     = 'https://github.com/philipp-kempgen/offer-accept-matcher'
	s.platform     = Gem::Platform::RUBY
	s.require_path = 'lib'
	s.executables  = []
	s.files        = Dir.glob( '{lib,bin}/**/*' ) + %w(
		README.md
	)
}


# Local Variables:
# mode: ruby
# indent-tabs-mode: t
# End:

