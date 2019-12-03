require "sinatra"
require "sinatra/namespace"
require_relative 'models.rb'
require_relative "api_authentication.rb"
require "json"
require 'fog'
require 'csv'
require 'httparty'


connection = Fog::Storage.new({
:provider                 => 'AWS',
:aws_access_key_id        => 'youraccesskey',
:aws_secret_access_key    => 'yoursecretaccesskey'
})

if ENV['DATABASE_URL']
	S3_BUCKET = "instagram"
else
	S3_BUCKET = "instagram-dev"
end

def placeholder
	halt 501, {message: "Not Implemented"}.to_json
end

if !User.first(email: "student@student.com")
	u = User.new
	u.email = "student@student.com"
	u.password = "student"
	u.bio = "Student"
	u.profile_image_url = "https://via.placeholder.com/1080.jpg"
	u.save
end

namespace '/api/v1' do
	before do
		content_type 'application/json'
	end

	#ACCOUNT MAINTENANCE

	#returns JSON representing the currently logged in user
	get "/my_account" do
		api_authenticate!
		halt 200, current_user.to_json(exclude: [:password, :role_id])
	end

	#let people update their bio
	patch "/my_account" do
		api_authenticate!
		if params["bio"] != nil
			current_user.bio = params["bio"]
			current_user.save
			halt 200, current_user.to_json(exclude: [:password, :role_id])
		else
			halt 422, {message: "Unable to update bio"}.to_json
		end
	end

	#let people update their profile image
	patch "/my_account/profile_image" do
		api_authenticate!
		if params[:image] && params[:image][:tempfile] && params[:image][:filename]
            begin
                token = "Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo1MH0._slEKogc9hiT8kZxg7gSkc97IFBN40aVcE3zPnYxeXE"
                file = params[:image][:tempfile]
                response = HTTParty.post("https://nameless-forest-80107.herokuapp.com/api/images", body: { image: file },  :headers => { "Authorization" => token} )
                data = JSON.parse(response.body)
 
                #make post
                current_user.profile_image_url = data["url"]
                current_user.save
                halt 200, {"message" => "Image updated"}.to_json
            rescue => e
                puts e.message
                halt 422, {message: "Unable to create image"}.to_json
            end
        end
	end

	#returns JSON representing all the posts by the current user
	#returns 404 if user not found
	get "/my_questions" do
		api_authenticate!
		q = Question.find_all{|p| p.user_id == current_user.id}
		if current_user != nil
			halt 200, q.to_json
		else
			halt 404, {message: "User not found"}.to_json
		end
	end

	#USERS

	#returns JSON representing the user with the given id
	#returns 404 if user not found
	get "/users/:id" do
		api_authenticate!
		selectedUser= User.get(params["id"])
		if selectedUser != nil
			halt 200, selectedUser.to_json(exclude: [:password, :role_id])
		else
			halt 404, {message: "User not found"}.to_json
		end
	end

	#returns JSON representing all the posts by the user with the given id
	#returns 404 if user not found
	get "/users/:user_id/questions" do
		api_authenticate!
		selectedUser= User.get(params["id"])
		if selectedUser != nil
			halt 200, selectedUser.questions.to_json
		else
			halt 404, {message: "User not found"}.to_json
		end
	end

	# Questions

	#returns JSON representing all the questions in the database
	get "/questions" do
		api_authenticate!
		halt 200, Question.all.to_json
	end

	#returns JSON representing the question with the given id
	#returns 404 if post not found
	get "/questions/:id" do
		api_authenticate!
		q = Question.get(params["id"])
		if q != nil
			halt 200, q.to_json(methods: [:thumbnail, :embed_code])
		else
			halt 404, {message: "Question could not be found"}.to_json
		end
	end

	#adds a new question to the database
	post "/questions" do
		api_authenticate!
		if params[:image] && params[:image][:tempfile] && params[:image][:filename]
            begin
                token = "Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo1MH0._slEKogc9hiT8kZxg7gSkc97IFBN40aVcE3zPnYxeXE"
                file = params[:image][:tempfile]
                response = HTTParty.post("https://nameless-forest-80107.herokuapp.com/api/images", body: { image: file },  :headers => { "Authorization" => token} )
                data = JSON.parse(response.body)
 
				#make post
				q = Question.new
				q.Title = params["title"]
				q.Description = params["description"]
				q.image_url = data["url"]
				q.Genre = params["genre"]
				q.Answered = false
				q.user_id = current_user.id
				q.save
				halt 200, q.to_json
            rescue => e
                puts e.message
                halt 422, {message: "Unable to create post"}.to_json
			end
		end
	end

	#updates the post with the given ID
	#only allow updating the caption, not the image
	patch "/questions/:id" do
		api_authenticate!
		q = Question.get(params["id"])
		if q != nil
			if q.user_id == current_user.id
				q.Description = params["description"]
				q.Title = params["title"]
				q.Genre = params["genre"]
				q.Bounty = params["bounty"]
				q.save
				halt 200, q.to_json
			else
				halt 401, {message: "Not authorized to delete post"}
			end
		else
			halt 404, {message: "Post not found"}
		end
	end

	#deletes the post with the given ID
	#returns 404 if post not found
	delete "/questions/:id" do
		api_authenticate!
		q = Question.get(params["id"])
		if q != nil
			if q.user_id == current_user.id
				q.destroy
			else
				halt 401, {message: "Not authorized to delete post"}
			end
		else
			halt 404, {message: "User not found"}
		end
	end

	#COMMENTS

	#returns JSON representing all the comments
	#for the post with the given ID
	#returns 404 if post not found
	get "/questions/:id/comments" do
		api_authenticate!
		p = Post.get(params["id"])
		c = p.comment
		if c != nil
			halt 200, c.to_json
		else
			halt 404, {messge: "Comment not found"}
		end
	end

	#adds a comment to the post with the given ID
	#accepts "text" parameter
	#returns 404 if post not found
	post "/questions/:id/comments" do
		api_authenticate!
		q = Question.get(params["id"])
		if q != nil
			c = Comment.new
			c.text = params["text"]
			c.post_id = params["id"]
			c.user_id = current_user.id
			c.save
			halt 200, c.to_json
		else
			halt 404, {messge: "Question not found"}
		end

	end

	#updates the comment with the given ID
	#only allows updating "text" property
	#returns 404 if not found
	#returns 401 if comment does not belong to current user
	patch "/comments/:id" do
		api_authenticate!
		c = Comment.first(id: params["id"])
		if c != nil
			if c.user_id == current_user.id
				c.text = params["text"]
				c.save
				halt 200, {message: "Successfully updated comment"}
			else
				halt 401, {message: "Can't update a comment that doesn't belong to you"}
			end
		else
			halt 404, {message: "Comment not found"}
		end
	end

	#deletes the comment with the given ID
	#returns 404 if not found
	#returns 401 if comment does not belong to current user
	delete "/comments/:id" do
		api_authenticate!
		c = Comment.first(id: params["id"])
		if c != nil
			if c.user_id == current_user.id
				c.destroy
				halt 200, {message: "Successfully deleted comment"}
			else
				halt 401, {message: "Can't delete a comment that doesn't belong to you"}
			end
		else
			halt 404, {message: "Post not found"}
		end
	end

	#ANSWERS
	get "/questions/:id/answers" do
		api_authenticate!
		q = Question.get(params["id"])
		a = q.answers
		if q.user_id = current_user.id
			if p != nil
				halt 200, l.to_json
			else
				halt 404, {messge: "Post not found"}
			end
		else
			halt 422, {messge: "Not authorized to view answers for this post"}
		end
	end

	#adds answer to question if not already answered
	post "/questions/:id/answer" do
		api_authenticate!
		a = Answer.first(question_id: params["id"], user_id: current_user.id)
		q = Question.get(params["id"])
		if !q.Answered
			if a == nil && !q.Answered
				a = Answer.new
				a.text = params["text"]
				a.user_id = current_user.id
				a.post_id = params["id"]
				a.save
				halt 200, {message: "Answer has been posted"}.to_json 
			else
				halt 404, {message: "You have already answered this question"}.to_json 
			end
		else
			halt 404, {message: "This question has already been answered"}.to_json 
		end
	end

	#checks if user posted answer
	#deletes answer
	delete "/questions/:id/answer" do
		api_authenticate!
		a = Answer.first(question_id: params["id"], user_id: current_user.id)
		if a.user_id == current_user.id
			if a != nil
				a.destroy
				halt 200, {message: "Successfully deleted Answer"}
			else
				halt 404, {message: "Can't delete an answer that doesn't exist"}
			end
		else
			halt 404, {message: "Can't delete an answer that doesn't belong to you"}
		end
	end

	#BOUNTIES
	get "/questions/:id/bounty" do
		api_authenticate!
		q = Question.get(params["id"])
		a = q.answers
		if q.user_id = current_user.id
			if p != nil
				halt 200, l.to_json
			else
				halt 404, {messge: "Post not found"}
			end
		else
			halt 422, {messge: "Not authorized to view answers for this post"}
	end

	#adds a bounty to a question and subtracts that amount from user account
	#returns 404 if question not found
	patch "/questions/:id/bounty" do
		api_authenticate!
		q = Question.get(params["id"])
		u = current_user
		if q != nil
			u.coins -= params["bounty"]
			q.Bounty += params["bounty"]
			u.save
			q.save
			halt 200, {message: "Your bounty has been added"}.to_json 
		else
			halt 404, {message: "Question does not exist"}.to_json 
		end
	end

end
