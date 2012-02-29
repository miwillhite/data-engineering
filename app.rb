%w( rubygems sinatra data_mapper dm-sqlite-adapter haml ).each do |dep| 
  require dep 
end



# Setup database
configure do
  
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/customer_data.db")  

  DataMapper::Logger.new(STDOUT, :debug)
  
end



# Define Models
class Item
  include DataMapper::Resource
  
  property :id,             Serial
  property :description,    String
  property :price_in_cents, Integer
  property :purchase_count, Integer, default: 0
  
  # Assocations
  belongs_to :merchant
  has n, :purchasers, through: Resource
end

class Merchant
  include DataMapper::Resource
  
  property :id,       Serial
  property :name,     String
  property :address,  String
  
  has n, :items
end

class Purchaser
  include DataMapper::Resource
  
  property :id,           Serial
  property :given_name,   String
  property :family_name,  String
  
  has n, :items, through: Resource
end

DataMapper.finalize
DataMapper.auto_migrate!



# Render the form to the user w/ upload instructions
get '/' do
  haml :index
end


# Process the data and render results
post '/' do
  
  # Read and parse the uploaded file
  file_contents = params['file'][:tempfile].read
  
  # Separate into rows, then columns
  rows = file_contents.split("\n").map { |row| row.split("\t") }
  
  # Grab the headers for display of results
  headers = rows.shift
  
  
  # Save the data - quick n' dirty
  rows.each do |row|
    
    # Align the headers with the data so that we can see what's happening!
    # e.g. [:some, 'thing'] => { some: 'thing' }
    mapped_row = Hash[*headers.zip(row).flatten]
    
    
    given_name, family_name = mapped_row['purchaser name'].split(' ')

    purchaser = Purchaser.first_or_create({
      given_name:   given_name,
      family_name:  family_name
    })

    
    merchant = Merchant.first_or_create({
      name:     mapped_row['merchant name'],
      address:  mapped_row['merchant address']
    })

    
    item = Item.first_or_create({
      description:    mapped_row['item description'],
      price_in_cents: mapped_row['item price'].to_i * 100,
      merchant_id:    merchant.id
    })

    
    # Update the purchase count
    item.purchase_count += mapped_row['purchase count'].to_i
    item.save

    
    # Add the item to the purchaser
    purchaser.items << item
    purchaser.save
    
  end
  
  
  
  # Calculate total revenue
  revenue_in_cents = Item.reduce(0) do |sum, item| 
    sum += item.price_in_cents*item.purchase_count
  end
  
  # Formatting logic borrowed from http://mikepence.wordpress.com/2007/05/05/formatting-us-dollars-with-ruby/
  @revenue = sprintf('$%0.2f', revenue_in_cents/100.0)
  
  
  # Re-render the view
  haml :index
  
  
end




enable :inline_templates

__END__

@@index

!!!
%html
  %body
    %h2 Please upload your tabular data file
    %form{ action: "/", enctype: "multipart/form-data", method: "POST" }
      %input{ type: "file", name: "file" }
      %input{ type: "submit" }
      
      = "<h1>Gross Revenue: #{@revenue}</h1>" if @revenue