require 'ladle'

module FeaturesHelpers
  def sign_in(user,password)
    logout
    visit new_user_session_path
    fill_in 'Username', with: user
    fill_in 'Password', with: password
    click_button 'Log in'
    expect(page).not_to have_text 'Invalid email or password.'
  end
end
