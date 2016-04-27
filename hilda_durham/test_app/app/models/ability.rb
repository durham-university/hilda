class Ability
  include Oubliette::AbilityBehaviour
  include Schmit::AbilityBehaviour
  include Trifle::AbilityBehaviour
  include Hilda::AbilityBehaviour

  def initialize(user)
    set_oubliette_abilities(user)
    set_schmit_abilities(user)
    set_trifle_abilities(user)
    set_hilda_abilities(user)
  end

end
