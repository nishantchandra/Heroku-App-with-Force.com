require "sinatra/base"
require 'force'
require "omniauth"
require "omniauth-salesforce"


class MyApp < Sinatra::Base

  configure do
    enable :logging
    enable :sessions
    set :show_exceptions, false
    set :session_secret, ENV['SECRET']
  end

  use OmniAuth::Builder do
    provider :salesforce, ENV['SALESFORCE_KEY'], ENV['SALESFORCE_SECRET']
  end

  before /^(?!\/(auth.*))/ do
    redirect '/authenticate' unless session[:instance_url]
  end


  helpers do
    def client
      @client ||= Force.new instance_url:  session['instance_url'],
                            oauth_token:   session['token'],
                            refresh_token: session['refresh_token'],
                            client_id:     ENV['SALESFORCE_KEY'],
                            client_secret: ENV['SALESFORCE_SECRET']
    end

  end


  get '/' do
    logger.info "Visited home page"
    @accounts= client.query("select Id, Name, Active__c, Phone from Account")
    erb :index
  end

  get '/newAccount' do
      erb :account
  end

  post '/newAccount' do
     Aname = params[:accountName]
     Aphone = params[:accountPhone]

     client.create('Account', Name: Aname, Phone: Aphone)
     redirect '/'
  end

  get '/destroy' do
    erb :destroy
  end

  post '/destroy' do
    Oobject = params[:object].to_s.capitalize
    Oid = params[:theId].to_s
    client.destroy(Oobject, Oid)
    redirect '/'
  end

  get '/update' do
    erb :update
  end

  post '/update' do
    Oobject = params[:object].to_s.capitalize
    Oid = params[:theId].to_s
    Ofield = params[:fieldValue].to_s.capitalize
    Ovalue = params[:newValue].to_s
    client.update(Oobject, Id: Oid, Name: Ovalue)
    redirect '/'
  end


  get '/authenticate' do
    redirect "/auth/salesforce"
  end


  get '/auth/salesforce/callback' do
    logger.info "#{env["omniauth.auth"]["extra"]["display_name"]} just authenticated"
    credentials = env["omniauth.auth"]["credentials"]
    session['token'] = credentials["token"]
    session['refresh_token'] = credentials["refresh_token"]
    session['instance_url'] = credentials["instance_url"]
    redirect '/'
  end

  get '/auth/failure' do
    params[:message]
  end

  get '/unauthenticate' do
    session.clear
    'Goodbye - you are now logged out'
  end

  error Force::UnauthorizedError do
    redirect "/auth/salesforce"
  end

  error do
    "There was an error.  Perhaps you need to re-authenticate to /authenticate ?  Here are the details: " + env['sinatra.error'].name
  end

  run! if app_file == $0

end
