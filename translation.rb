#  translation.rb
#  
#  Utilities for translating text to various languages
#  
#  

require 'yaml'

# Translation module
module Translation

    # Module to mix with Object
    module TranslationMixin
        
        def tr(key)
            Translation.translate key
        end
    end

    FILENAME = 'translations.yml'

    # Load translations for language with specified id
	def self.init_for_language(lang_id)
		all_langs = YAML.load_file FILENAME
        @@translations = all_langs[lang_id]
	end
    
    # Get translation for specified key
    def self.translate(key)
        key_name = key.instance_of?(String) ? key : key.to_s
        @@translations[key_name]
    end

end

include Translation::TranslationMixin
