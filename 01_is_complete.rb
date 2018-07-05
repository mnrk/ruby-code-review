################################# OLD ###################################

def is_complete?
  basics_filled = name.present? && identifier.present? && address.present? && protocols.count > 0
  if basics_filled
    return true if primary_contact.present?
  end
  false
end

################################# NEW ###################################

def basics_filled?
  name.present? && identifier.present? && address.present? && protocols.count > 0
end

def complete? # is should not be in the name of the method
  return basics_filled? && primary_contact.present?
end