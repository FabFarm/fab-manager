  class API::PlansController < API::ApiController
  before_action :authenticate_user!, except: [:index]

  def index
    @attributes_requested = params[:attributes_requested]
    @plans = Plan.all
    @plans = @plans.where(group_id: params[:group_id]) if params[:group_id]
    if params[:shallow]
      render :shallow_index
    else
      render :index
    end
  end

  def show
    @plan = Plan.find(params[:id])
  end

  def create
    authorize Plan
    if plan_params[:type] and plan_params[:type] == 'PartnerPlan'

      partner = User.find(params[:plan][:partner_id])

      if plan_params[:group_id] == 'all'
        plans = PartnerPlan.create_for_all_groups(plan_params)
        if plans
          plans.each { |plan| partner.add_role :partner, plan }
          render json: { plan_ids: plans.map(&:id) }, status: :created
        else
          render status: :unprocessable_entity
        end

      else
        @plan = PartnerPlan.new(plan_params)
        if @plan.save
          partner.add_role :partner, @plan
          render :show, status: :created
        else
          render json: @plan.errors, status: :unprocessable_entity
        end
      end
    else
      if plan_params[:group_id] == 'all'
        plans = Plan.create_for_all_groups(plan_params)
        if plans
          render json: { plan_ids: plans.map(&:id) }, status: :created
        else
          render status: :unprocessable_entity
        end
      else
        @plan = Plan.new(plan_params)
        if @plan.save
          render :show, status: :created, location: @plan
        else
          render json: @plan.errors, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    @plan = Plan.find(params[:id])
    authorize @plan
    if @plan.update(plan_params)
      render :show, status: :ok
    else
      render json: @plan.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @plan = Plan.find(params[:id])
    authorize @plan
    @plan.destroy
    head :no_content
  end

  private
    def plan_params
      if @parameters
        @parameters
      else
        @parameters = params
        @parameters[:plan][:amount] = @parameters[:plan][:amount].to_i * 100.0 if @parameters[:plan][:amount]
        @parameters[:plan][:prices_attributes] = @parameters[:plan][:prices_attributes].map do |price|
          { amount: price[:amount].to_i * 100.0, id: price[:id] }
        end if @parameters[:plan][:prices_attributes]

        @parameters = @parameters.require(:plan).permit(:base_name, :type, :group_id, :amount, :interval, :interval_count, :is_rolling,
            :training_credit_nb,
            :ui_weight,
            plan_file_attributes: [:id, :attachment, :_destroy],
            prices_attributes: [:id, :amount]
        )

        @parameters
      end
    end
end
