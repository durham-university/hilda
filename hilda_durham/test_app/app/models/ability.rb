class Ability
  include Oubliette::AbilityBehaviour
  include Schmit::AbilityBehaviour

  def initialize(user)
    set_oubliette_abilities(user)
    set_schmit_abilities(user)
  end

end
