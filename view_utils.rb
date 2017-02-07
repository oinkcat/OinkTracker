#  view_utils.rb
#  
#  View related utilities
#  
#  

# View utils
module View
    
    TilesDirPublic = 'tiles'
    TilesDir = "./public/#{TilesDirPublic}"
    
    # Get user picture by login (or default if pic not exists)
    def self.user_pic(login)
        tile_filename = "#{TilesDir}/#{login}.jpg"
        pic_name = File.exists?(tile_filename) ? login : 'default'
        
        return "/#{TilesDirPublic}/#{pic_name}.jpg"
    end
    
end
