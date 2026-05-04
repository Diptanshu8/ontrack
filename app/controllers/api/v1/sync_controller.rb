module Api; module V1
  class SyncController < BaseController
    # Returns the user's data-version token. iOS clients store this and skip
    # list/report refetches on cold launch when the token hasn't changed since
    # last fetch. Token bumps via `belongs_to :user, touch: :data_updated_at`
    # on every user-owned model write.
    def version
      render json: { version: @current_user.data_updated_at.to_i }
    end
  end
end; end
