class Vote < ActiveRecord::Base
  @@public_key = nil
  attr_accessor :generated_vote_checksum # Used for testing purposes only as this generated checksum is transferred over to the final_split_vote before counting

  def self.generate_encrypted_checksum(voter_identity_hash,payload_data,remote_ip,neighborhood_id,session_id)
    @@public_key = OpenSSL::PKey::RSA.new(File.read(Rails.root.join("config","rvk_public_key.pem"))) unless @@public_key
    vote_checksum = Vote.generate_checksum(voter_identity_hash,payload_data,remote_ip,neighborhood_id,session_id)
    Rails.logger.info("Public key: #{@@public_key} Checksum: #{vote_checksum}")
    encrypted = Base64.encode64(@@public_key.public_encrypt(vote_checksum))
    encrypted.length
    encrypted
  end

  def self.generate_checksum(voter_identity_hash,payload_data,remote_ip,neighborhood_id,session_id)
    Digest::SHA1.hexdigest [voter_identity_hash,payload_data,remote_ip,neighborhood_id,session_id].join(" ")
  end

  def self.split_and_generate_final_votes!
    FinalSplitVote.delete_all
    Vote.all_latest_votes_by_distinct_voters.each do |vote|
      generated_vote_checksum = Vote.generate_encrypted_checksum(vote.user_id_hash, vote.payload_data, vote.client_ip_address, vote.neighborhood_id, vote.session_id)
      FinalSplitVote.create(:neighborhood_id => vote.neighborhood_id, :vote_id=>vote.id, :payload_data=>vote.payload_data,
                            :encrypted_vote_checksum => vote.encrypted_vote_checksum, :generated_vote_checksum=> generated_vote_checksum)
    end
  end

  def self.all_latest_votes_by_distinct_voters
    query = %q{
        SELECT  id, created_at, neighborhood_id, payload_data, user_id_hash, client_ip_address, encrypted_vote_checksum, session_id
        FROM    votes vs
        WHERE   id =
                  (
                    SELECT  id
                    FROM    votes other_votes
                    WHERE   other_votes.user_id_hash = vs.user_id_hash
                    ORDER BY
                            created_at DESC
                    LIMIT 1
                  )}

    query += " ORDER BY created_at DESC"
    Vote.find_by_sql(query)
  end
end
