################################# OLD ###################################

def self.create_or_update_study(params, study = nil)
  ActiveRecord::Base.transaction do
    is_new = true
    if study.present?
      is_new = false
      study.must_be_in_editable_state!
    end
    study ||= Study.new
    study.name = params[:name]
    study.identifier = params[:identifier]
    study.sponsor = params[:sponsor]
    study.therapy_relative_start = params[:therapy_relative_start]
    if params[:address].nil?
      study.address = study.sponsor.addresses.where(is_primary: true).first
    else
      if is_new || study.address.is_primary
        address = SponsorAddress.new(params[:address])
        address.sponsor = study.sponsor
        address.save!
        study.address = address
      else
        study.address.update_attributes!(params[:address])
      end
    end
    study.resolve_state(params)
    study.save!
    study.replicate_into_master
    study.set_logo(params[:logo_file_id]) if params[:logo_file_id].present?
    Contact.assign_contact(study, params[:primary_contact], 'primary_contact')
    if params[:manager].present?
      Contact.assign_contact(study, params[:manager], 'manager')
    end
    # Replicate possibly changed identifier/name to contacts
    study.contacts.each(&:update_role_in_study) unless is_new
    study
  end
end

################################# NEW ###################################
# ^^ This logic is too intertwined in between multiple models, should not be in a model at all
# we can treat the model as a repository and move all complex logic to a different layer (service?)

def logo_file_id= file_id
  set_logo(file_id) if file_id
end


def set_contact(contact, role)                                                      # move everything thats repeated here to stay DRY
  Contact.assign_to(self, contact, role) if contact
end

def primary_contact= contact
  set_contact(contact, :primary_contact)
end

def manager= contact
  set_contact(contact, :manager)
end

def update_roles_of_contacts!
  contacts.each(&:update_role_in_study)
end

def update_address_from_params address_params                                       # in general, it is better to make address immutable and this whole block would be much simpler
  if address_params                                                                 # can use this instead of #present? or #nil?
    if new_record? || address.primary?                                              # new_record? already exists
      self.address = SponsorAddress.create(address_params.merge(sponsor: sponsor))  # create instead of new and save!
    else
      address.update_attributes!(address_params)
    end
  else
    self.address = sponsor.address.primary.first
  end
end

def self.create_or_update_study(params, study = nil)
  study.must_be_in_editable_state!

  ActiveRecord::Base.transaction do
    study ||= Study.new
    study.attributes = params.slice(:name, :identifier, :sponsor, :therapy_relative_start, 
                          :logo_file_id, :primary_contact, :manager)
    study.update_address_from_params(params[:address])
    study.resolve_state(params)
    study.save!
    study.replicate_into_master
    study.update_roles_of_contacts! unless study.new_record?
    study
  end
end



################################# OLD ###################################
