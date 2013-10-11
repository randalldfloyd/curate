require 'spec_helper'

describe 'Creating an etd' do
  let(:user) { FactoryGirl.create(:user) }

  it "should allow me to attach the link on the create page" do
    login_as(user)
    visit root_path
    click_link "Get Started"
    click_link "Submit a work"
    classify_what_you_are_uploading 'Etd'
    within '#new_etd' do
      fill_in "Title", with: "umami sartorial Williamsburg church-key"
      fill_in "Creator", with: "Test etd creator"
      fill_in "Abstract", with: "Some stuff"
      fill_in "Country", with: "Belgium"
      fill_in "Advisor", with: "Marcy Holmes"
      fill_in "Subject", with: "Paleoethnography"
      #Date created
      select "2013", from: "etd[date_created(1i)]"
      select "October", from: "etd[date_created(2i)]"
      select "4", from: "etd[date_created(3i)]"
      select(Sufia.config.cc_licenses.keys.first, from: I18n.translate('sufia.field_label.rights'))
      check("I have read and accept the contributor license agreement")
      click_button("Create Etd")
    end

    # then I should find it in the search results.
    fill_in 'Search Curate', with: 'sartorial umami'
    click_button 'Go'
    within('#documents') do
      expect(page).to have_link('umami sartorial Williamsburg church-key') #title
      expect(page).to have_selector('dd', text: 'Test etd creator')
      expect(page).to have_selector('dd', text: 'Paleoethnography')
      expect(page).to have_selector('dd', text: '2013-10-04')
    end
  end
end

describe 'Viewing an ETD that is private' do
  let(:user) { FactoryGirl.create(:user) }
  let(:work) { FactoryGirl.create(:private_etd, title: "Sample work" ) }

  it 'should show a stub indicating we have the work, but it is private' do
    login_as(user)
    visit curation_concern_etd_path(work)
    page.should have_content('Unauthorized')
    page.should have_content('The etd you have tried to access is private')
    page.should have_content("ID: #{work.pid}")
    page.should_not have_content("Sample work")
  end
end


