require 'data_mapper' # metagem, requires common plugins too.

# need install dm-sqlite-adapter
# if on heroku, use Postgres database
# if not use sqlite3 database I gave you
if ENV['DATABASE_URL']
  DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
else
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/app.db")
end

class User
    include DataMapper::Resource
    property :id, Serial
    property :email, Text
    property :password, Text
    property :coins, Integer
    property :created_at, DateTime
    property :role_id, Integer, default: 1

    def administrator?
        return role_id == 0
    end 

    def user?
        return role_id != 0
    end
    
    def login(password)
    	return self.password == password
    end
end

class Question
  include DataMapper::Resource
    property :id, Serial
    property :Title, Text
    property :Description, Text
    property :Genre, Text
    property :image_url, Text
    property :Answered, Boolean
    property :created_at,  DateTime
    property :role_id, Integer, default: 1
end

class Answer
  include DataMapper::Resource
    property :id, Serial
    property :text, Text
    property :image_url, Text
    property :question_id,  Integer
    property :created_at,  DateTime
    property :role_id, Integer, default: 1
end



# Perform basic sanity checks and initialize all relationships
# Call this when you've defined all your models
DataMapper.finalize

# automatically create the post table
User.auto_upgrade!
Question.auto_upgrade!

DataMapper::Model.raise_on_save_failure = true  # globally across all models