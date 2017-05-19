class Ability
  unless Rails.env.test?
    include Oubliette::AbilityBehaviour
    include Schmit::AbilityBehaviour
    include Trifle::AbilityBehaviour
  end
  include Hilda::AbilityBehaviour

  def initialize(user)
    unless Rails.env.test?
      set_oubliette_abilities(user)
      set_schmit_abilities(user)
      set_trifle_abilities(user)
    end
    set_hilda_abilities(user)
  end

end
