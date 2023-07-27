# This is a PORO made to separate SNS related logic from the main page program (Separation of Concerns)
# At the time being we only use Facebook, LinkedIn and Google+.
# facebook is using an old version of a gem called Koala. I couldn't find a gem for our current Rails and Ruby versions
# so I had to code all the REST connections with LinkedIn and Google+
#
#
# TODO: Make Facebook services connect through REST API for consistency

class SnsLogin
  attr_accessor :request, :params, :url

  # Gem for connecting with facebook's graph tools
  require 'koala'

  # Key for anti crosssite created by Carlos
  STATE = 'XXXXXX'
  AVAILABLE_SERVICES = ['facebook', 'linkedin', 'googleplus']

  # General information required for connecting via the REST API of the SNS
  SNS = {
    # LINKEDIN
    :linkedin => {
      :auth_url => 'https://www.linkedin.com/oauth/v2/authorization?',
      :scope => 'r_basicprofile%20r_emailaddress',
      :access_token_url => 'https://www.linkedin.com/uas/oauth2/accessToken',
      :profile_url => "https://api.linkedin.com/v1/people/~:(id,firstName,lastName,emailAddress,location)?format=json&oauth2_access_token=",
      :api_key => 'XXXXXX',
      :api_secret => 'XXXXXX'
    },

    # GOOGLE+
    :googleplus => {
      :auth_url => 'https://accounts.google.com/o/oauth2/v2/auth?',
      :scope => 'email%20profile',
      :access_token_url => 'https://www.googleapis.com/oauth2/v4/token',
      :profile_url => 'https://www.googleapis.com/oauth2/v1/userinfo?alt=json&access_token=',
      :api_key => 'XXXXXX',
      :api_secret => 'XXXXXX'
    }
  }

  # Build the auth url so the user is redirected to it
  # @param [CgiRequest] request Rails request object as is
  # @param [String] service Name of the service (linkedin or googleplus) *Facebook uses koala gem
  # @return [String] Processed url for redirection
  def SnsLogin.auth_url(request, service)
    url_prefix = (DJ_LANGUAGE == 'ja')? '' : DJ_LANGUAGE + '/'
    
    # URL to return to after SNS authentication
    @redirect_uri = CGI.escape("https://#{request.host}/#{url_prefix}member/#{service}")
    url = get_auth_url(service)

    return url
  end

  # After we get the authorization code and access token from the SNS service,
  # this method gets the profile of the user so we can login or register
  # @param [CgiRequest] request Rails request object as is
  # @param [String] service Name of the service (linkedin, googleplusi, facebook)
  # @param [String] auth_code Authorization code retrieved from the SNS
  # @param [String] access_token Access token retrieved from the SNS
  # @return [Hash] Member infor (Name, email. location, birthday)
  def SnsLogin.get_profile(request, service, auth_code = nil, access_token = nil)
    access_token = get_access_token(request, auth_code, service) if access_token.nil?
    service = service.to_sym

    # Facebook used Koala gem
    if service == :facebook
      graph = Koala::Facebook::API.new(access_token)
      profile = graph.get_object('me', { :fields => 'first_name, last_name, email, location, birthday' })
    else
    # Linkedin and Googleplus use regular REST API
      profile = JSON.parse(URI.parse("#{SNS[service][:profile_url]}#{access_token}").read)
    end


    # Add the access token so we can keep using it in the returned object
    return profile.merge({'access_token' => access_token})
  end

  # Creates member and member login based on data taken from sns login service.
  # @param [Hash] profile
  # Must cointain at least:
  # email (linkedin: emailAddress, facebook: email, googleplus: email)
  # first name (linkedin: firstName, facebook: first_name, googleplus: given_name)
  # last name(linkedin: lastName, facebook: last_name, googleplus: family_name)
  # 
  # @param [String] service Name of the service (linkedin, googleplusi, facebook)
  # @param [CgiRequest] request Rails request object as is
  # @return [Hash] Hash with the data to create a new EmailRegistration object
  # I wanted to deal with the least ammoung of models in this PORO
  def SnsLogin.sns_register(profile, service, request)
    if profile['location']
      location = Location.find :first, :conditions => ['parent_id IN (210, 215, 217, 220, 230, 240) AND description_en LIKE (?)', profile['location']['name'].split(',').last.strip] 
    end

    # Strings contained in mobile user_agents
    is_mobile_regex = /iphone|ipod|android.*mobile|android.*mobi|windows phone|blackberry|symbian/i
    # Register what SNS the user is logging-in/registering from
    extra = "#{service}=#{profile['access_token']}"
    # Set a temporarypassword to be able to start registration, this will be later changed to a more secure password when the real registration is done (CHECK member_controller)
    pwd = "XXXXXX"
    
    # Check email_registration.rb model for further details
    email_registration = {
      :email => profile['email'] || profile['emailAddress'], # email is facebook, emailAddress is linkedin
      :key => 'snslogin',
      :user_name => profile['email'] || profile['emailAddress'], # email is facebook, emailAddress is linkedin
      :salt => pwd,
      :pwhash => pwd,
      :default_area_id => location.nil? ? nil : location.parent_id,
      :default_country_id => location.nil? ? nil : location.id,
      :login_from_where => Constants::LANGUAGE_IDS[DJ_LANGUAGE],
      :where_know_daijob => 1,
      :is_working_abroad => request.host.include?('workingabroad'),
      :mailmaga_subscriptions => DJ_LANGUAGE == 'ja' ? 1 : 8,
      :extra => extra,
      :receive_jobmail => true,
      :register_from_smartphone => !(request.env['HTTP_USER_AGENT'].nil? ? '' : request.env['HTTP_USER_AGENT']) [is_mobile_regex].nil?

    }

    return email_registration
  end

  # Create a member with the SNS information
  # @param [CgiRequest] request Rails request object as is
  # @param [String] service Name of the service (linkedin, googleplusi, facebook)
  # @param [String] access_token Access token retrieved from the SNS
  # @return [Hash] With information to create a member object
  def SnsLogin.member_info(request, service, access_token)
    profile = SnsLogin.get_profile(request, service, nil, access_token)

    member = {
     :firstname => (profile['first_name'] || profile['firstName'] || profile['given_name']).gsub(/[A-Za-z\s]/, '') == '' ? (profile['first_name'] || profile['firstName'] || profile['given_name']) : '',
     :surname => (profile['last_name'] || profile['lastName'] || profile['family_name']).gsub(/[A-Za-z\s]/, '') == '' ? (profile['last_name'] || profile['lastName'] || profile['family_name']) : '',
     :birthday => profile['birthday'] ? profile['birthday'].gsub('/', '-') : nil,
    }

    return member
  end

  # Create a member_login with the SNS information
  # @param [CgiRequest] request Rails request object as is
  # @param [String] service Name of the service (linkedin, googleplusi, facebook)
  # @param [String] access_token Access token retrieved from the SNS
  # @return [Hash] With information to create a member_login object
  def SnsLogin.member_login_info(request, service, access_token)
    profile = SnsLogin.get_profile(request, service, nil, access_token)

    member_login = {
      "#{service}_id".to_sym => profile['id']
    }

    return member_login
  end

  # ONLY USED BY GOOGLE+ AND LINKEDIN AT THE MOMENT
  # Make a REST conenction with the SNS to get an access token for this session.
  # @param [CgiRequest] request Rails request object as is
  # @param [String] auth_code Auhtorization token retrieved from the SNS
  # @param [String] service Name of the service (linkedin, googleplusi, facebook)
  # @return [String] Access token
  def self.get_access_token(request, auth_code, service)
    url_prefix = (DJ_LANGUAGE == 'ja')? '' : DJ_LANGUAGE + '/'
    redirect_uri = "https://#{request.host}/#{url_prefix}member/#{service}"
    service = service.to_sym

    url = URI.parse(SNS[service][:access_token_url])
    req = Net::HTTP::Post.new(url.path)
    req.form_data = {
      :grant_type => 'authorization_code',
      :code => auth_code,
      :redirect_uri => redirect_uri,
      :client_id => SNS[service][:api_key],
      :client_secret => SNS[service][:api_secret]
    } 

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')
    access_token_response = http.request(req)

    access_token = JSON.parse(access_token_response.body)['access_token']
  end

  # Build the url to connect to the SNS service
  # @param [String] service Name of the service (linkedin or googleplus) *Facebook uses koala gem
  # @return [String] Url to connect to the REST API
  def self.get_auth_url(service)
    service = service.to_sym
    params = {
      :response_type => 'code',
      :client_id => SNS[service][:api_key],
      :redirect_uri => @redirect_uri,
      :state => STATE,
      :scope => SNS[service][:scope]
    }

    url = SNS[service][:auth_url] + params.to_a.collect{ |x| "#{x[0]}=#{x[1]}" }.join('&')
  end

end
