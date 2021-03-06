class DressmakerProfilesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]
  before_action :set_dressmaker, only: %i[show edit update]

  def index
    # for dropdown filter
    @specialities = Speciality.all

    if params[:query].present?
      @dressmakers = policy_scope(DressmakerProfile).global_search(params[:query])
      @dressmakers_users = @dressmakers.collect(&:user)
      pin_markers(@dressmakers_users)
    else
      @dressmakers = policy_scope(DressmakerProfile)
      @dressmakers_users = @dressmakers.collect(&:user)
      pin_markers(@dressmakers_users)
    end

    if params[:dressmaker_profile].present? && params[:dressmaker_profile][:speciality_name].present?
      @dressmakers = @dressmakers.global_search(params[:dressmaker_profile][:speciality_name])
      @dressmakers_users = @dressmakers.collect(&:user)
      pin_markers(@dressmakers_users)
    end
    # dressmakers = policy_scope(DressmakerProfile).order(created_at: :desc) eventually order by review ratings?
  end

  def show
    session[:dressmaker_id] = params[:id]
    @order = Order.new
    @reviews = Review.all
    @fabrics = ["Linen", "Cotton", "Silk"]
    @photos = @dressmaker.photos.all
    @specialities = @dressmaker.specialities
    # @clothing_types = UserClothingType.where(:dressmaker_profile => @dressmaker)
    @clothing_types = @dressmaker.clothing_types
    skip_authorization
  end

  def edit
    @photo = @dressmaker.photos.build
    @clothing_types = ClothingType.all

    authorize @dressmaker
  end

  def update
    authorize @dressmaker

    if @dressmaker.update(dressmaker_params)
      # handle photo upload
      if params[:photos].present?
        params[:photos]['url'].each do |url|
          @photo = @dressmaker.photos.create!(url: url, dressmaker_profile_id: @dressmaker.id)
        end
      end

      # handle speciality selection
      if params[:speciality_ids].present?
        params[:dressmaker_profile][:speciality_ids].each do |speciality_id|
          unless speciality_id == ""
            UserSpeciality.create!(
              speciality: Speciality.find(speciality_id),
              dressmaker_profile: @dressmaker
            )
          end
        end
      end

      # handle clothing types
      params_arr = params[:dressmaker_profile][:clothing_type_ids].map(&:to_i)
      current_clothing_types_arr = @dressmaker.user_clothing_types.ids
      remove_clothing_type_arr = current_clothing_types_arr - params_arr

      remove_clothing_type_arr.each do |clothing_type_id|
        # raise
        UserClothingType.delete(clothing_type_id)
      end

      params_arr.each do |clothing_type|
        if !current_clothing_types_arr.include?(clothing_type.to_i)
          UserClothingType.create!(
            clothing_type: ClothingType.find(clothing_type),
            dressmaker_profile: @dressmaker
          )
        end
      end

      redirect_to dressmaker_profile_path
    else
      render 'edit'
    end
  end

  def destroy
    # to be confirmed
  end

  private

  def pin_markers(users)
    @dressmakers_users = []
    users.each do |user|
      @dressmakers_users << user if user.latitude.present? && user.longitude.present?
    end
    @dressmakers_users
    @markers = @dressmakers_users.map do |user|
      {
        lng: user.longitude,
        lat: user.latitude,
        infoWindow: render_to_string(partial: "infowindow", locals: { user: user })
      }
    end
  end

  def dressmaker_params
    params.require(:dressmaker_profile).permit(
      :username, :bio, :avatar, :speciality_ids, :fb_url, :insta_url,
      :street_address, :street_address_2, :country, :post_code,
      photos_attributes: [:id, :dressmaker_profile_id, :url]
    )
  end

  def set_dressmaker
    @dressmaker = DressmakerProfile.find(params[:id])
  end
end
