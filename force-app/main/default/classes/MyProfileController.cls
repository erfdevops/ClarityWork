public without sharing class MyProfileController {

    @AuraEnabled(cacheable=true)
    public static Boolean isProfileEditAllowed() {
        try {

            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Allow_Profile_Edit__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
           
            if (settings.isEmpty()) {
                 System.debug('Error checking Allow_Profile_Edit__c: No settings found');
                return true;
            }
            return settings[0].Allow_Profile_Edit__c;
        } catch (Exception e) {
            System.debug('Error checking Allow_Profile_Edit__c: ' + e.getMessage());
            return true;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getEmployeeData(String userId) {
        try {
            // Check read access on User and Contact
            if (!User.sObjectType.getDescribe().isAccessible() || !Contact.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have access to read profile data.');
            }
            
            // Get the user's associated contact
            User currentUser = [SELECT Id, Email, ContactId FROM User WHERE Id = :userId LIMIT 1];
            
            if (currentUser.ContactId != null) {
                List<Contact> contacts = [
                    SELECT 
                        Id,
                        FirstName,
                        LastName,
                        Email,
                        Phone,
                        Birthdate,
                        MailingStreet,
                        MailingCity,
                        MailingState,
                        MailingPostalCode,
                        MailingCountry,
                        Retirement_Date__c
                    FROM Contact
                    WHERE Id = :currentUser.ContactId
                    LIMIT 1
                ];
                
                if (!contacts.isEmpty()) {
                    return buildContactMap(contacts[0]);
                }
            }
            
            return new Map<String, Object>();
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving contact data: ' + e.getMessage());
        }
    }

    public static Map<String, Object> buildContactMap(Contact contact) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('Id', contact.Id);
        result.put('FirstName', contact.FirstName);
        result.put('LastName', contact.LastName);
        result.put('Email', contact.Email);
        result.put('Phone', contact.Phone);
        result.put('Birthdate', contact.Birthdate);
        result.put('MailingStreet', contact.MailingStreet);
        result.put('MailingCity', contact.MailingCity);
        result.put('MailingState', contact.MailingState);
        result.put('MailingPostalCode', contact.MailingPostalCode);
        result.put('MailingCountry', contact.MailingCountry);
        result.put('Retirement_Date__c', contact.Retirement_Date__c);
        return result;
    }
    
    @AuraEnabled
    public static void updateEmployeeData(String recordId, Map<String, String> updateData) {
        try {
      
            
            Contact contact = new Contact(Id = recordId);
            
            // Update email if provided
            String email = updateData.get('email');
            if (String.isNotBlank(email)) {
                contact.Email = email;
            }
            
            // Update phone if provided
            String phoneNumber = updateData.get('phoneNumber');
            if (String.isNotBlank(phoneNumber)) {
                contact.Phone = phoneNumber;
            }
            
            // Update birthdate if provided
            String birthdate = updateData.get('birthdate');
            if (String.isNotBlank(birthdate)) {
                contact.Birthdate = Date.valueOf(birthdate);
            }
            
            // Update mailing street if provided
            String addressLine1 = updateData.get('addressLine1');
            if (String.isNotBlank(addressLine1)) {
                contact.MailingStreet = addressLine1;
            }
            
            // Update mailing city if provided
            String city = updateData.get('city');
            if (String.isNotBlank(city)) {
                contact.MailingCity = city;
            }
            
            // Update mailing state if provided
            String state = updateData.get('state');
            if (String.isNotBlank(state)) {
                contact.MailingState = state;
            }
            
            // Update mailing postal code if provided
            String postalCode = updateData.get('postalCode');
            if (String.isNotBlank(postalCode)) {
                contact.MailingPostalCode = postalCode;
            }
            
            // Update mailing country if provided
            String country = updateData.get('country');
            if (String.isNotBlank(country)) {
                contact.MailingCountry = country;
            }
            
            // Update retirement date if provided
            String retirementDate = updateData.get('retirementDate');
            if (String.isNotBlank(retirementDate)) {
                contact.Retirement_Date__c = Date.valueOf(retirementDate);
            }
            
            update contact;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating contact data: ' + e.getMessage());
        }
    }
}