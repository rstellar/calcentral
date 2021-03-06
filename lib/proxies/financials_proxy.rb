class FinancialsProxy < BaseProxy

  include ClassLogger

  APP_ID = "CFV"

  def initialize(options = {})
    super(Settings.financials_proxy, options)
  end

  def get
    request("/student/#{lookup_student_id}", "financials")
  end

  def request(path, vcr_cassette, params = {})
    self.class.fetch_from_cache(@uid) do
      student_id = lookup_student_id
      if student_id.nil?
        logger.info "Lookup of student_id for uid #@uid failed, cannot call CFV API path #{path}"
        return nil
      else
        url = "#{Settings.financials_proxy.base_url}#{path}"
        logger.info "Fake = #@fake; Making request to #{url} on behalf of user #{@uid}, student_id = #{student_id}; cache expiration #{self.class.expires_in}"
        begin
          response = FakeableProxy.wrap_request(APP_ID + "_" + vcr_cassette, @fake, {match_requests_on: [:method, :path]}) {
            HTTParty.get(
              url,
              digest_auth: {username: Settings.financials_proxy.username, password: Settings.financials_proxy.password}
            )
          }
          if response.code >= 400
            unless response.code == 404
              logger.error "Connection failed: #{response.code} #{response.body}; url = #{url}"
            end
            return nil
          end

          logger.debug "Remote server status #{response.code}; url = #{url}"
          {
            body: JSON.parse(response.body),
            status_code: response.code
          }
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
          logger.error "Connection to url #{url} failed: #{e.class} #{e.message}"
          {
            body: "Remote server unreachable",
            status_code: 503
          }
        end
      end
    end
  end
end
