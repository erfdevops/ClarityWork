public without sharing class NavigationBarTopController {
    
    @AuraEnabled(cacheable=true)
    public static Boolean isUserMember() {
        try {
            Id currentUserId = UserInfo.getUserId();
            System.debug('Checking if user is member - User ID: ' + currentUserId);
            
            // Get the current user's contact
            List<User> users = [
                SELECT Id, ContactId 
                FROM User 
                WHERE Id = :currentUserId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                System.debug('No user found for ID: ' + currentUserId);
                return false;
            }
            
            Id contactId = users[0].ContactId;
            System.debug('Contact ID found: ' + contactId);
            
            // Check if user has a contact (Member)
            if (contactId == null) {
                System.debug('User has no associated Contact - Not a Member');
                return false;
            }
            
            // Verify contact exists and has proper RecordType for Member
            List<Contact> contacts = [
                SELECT Id, RecordTypeId, RecordType.Name
                FROM Contact 
                WHERE Id = :contactId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                System.debug('No contact found with ID: ' + contactId);
                return false;
            }
            
            Contact contact = contacts[0];
            // Check if contact has a Member record type (you may need to adjust the record type name)
            Boolean isMember = contact.RecordType.Name == 'Member';
            System.debug('Contact found - Is Member: ' + isMember);
            
            return isMember;
            
        } catch (Exception e) {
            System.debug('Error checking membership status: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static ConsultantData getConsultantData() {
        try {
            Id currentUserId = UserInfo.getUserId();
            System.debug('Current User ID: ' + currentUserId);
            
            // Get the current user's contact
            List<User> users = [
                SELECT Id, ContactId 
                FROM User 
                WHERE Id = :currentUserId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                System.debug('No user found for ID: ' + currentUserId);
                return new ConsultantData();
            }
            
            Id contactId = users[0].ContactId;
            System.debug('Contact ID found: ' + contactId);
            
            if (contactId == null) {
                System.debug('User has no associated Contact');
                return new ConsultantData();
            }
            
            // Get contact with consultant lookup
            List<Contact> contacts = [
                SELECT Id, Retire_Now_Consultant__c, Retire_Now_Consultant__r.Name, 
                       Retire_Now_Consultant__r.Phone__c, Retire_Now_Consultant__r.User__c
                FROM Contact 
                WHERE Id = :contactId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                System.debug('No contact found with ID: ' + contactId);
                return new ConsultantData();
            }
            
            Contact contact = contacts[0];
            System.debug('Contact found: ' + contact.Id);
            
            if (contact.Retire_Now_Consultant__c == null) {
                System.debug('No Retire Now Consultant assigned to this contact');
                return new ConsultantData();
            }
            
            System.debug('Employee/Consultant found: ' + contact.Retire_Now_Consultant__r.Name);
            System.debug('Consultant Phone: ' + contact.Retire_Now_Consultant__r.Phone__c);
            
            ConsultantData consultantData = new ConsultantData();
            consultantData.name = contact.Retire_Now_Consultant__r.Name;
            consultantData.phone = contact.Retire_Now_Consultant__r.Phone__c;
            consultantData.hasData = true;
            
            // Get photo URL from employee's user record
            String photoUrl = getConsultantPhotoUrl(contact.Retire_Now_Consultant__r.User__c);
            consultantData.photoUrl = photoUrl;
            
            System.debug('Returning consultant data: ' + consultantData.name);
            System.debug('Final photoUrl: ' + consultantData.photoUrl);
            return consultantData;
            
        } catch (Exception e) {
            System.debug('Error getting consultant data: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new ConsultantData();
        }
    }
    
    private static String getConsultantPhotoUrl(Id userIdToQuery) {
        System.debug('===== START PHOTO RETRIEVAL =====');
        System.debug('Employee User ID: ' + userIdToQuery);
        
        if (userIdToQuery == null) {
            System.debug('Employee has no User__c value');
            return null;
        }
        
        try {
            if (!Schema.sObjectType.User.fields.SmallPhotoUrl.isAccessible()) {
                System.debug('SmallPhotoUrl field is not accessible');
                return null;
            }
            
            List<User> employees = [
                SELECT Id, SmallPhotoUrl 
                FROM User 
                WHERE Id = :userIdToQuery 
                LIMIT 1
            ];
            
            System.debug('Employee query returned ' + employees.size() + ' records');
            
            if (employees.isEmpty()) {
                System.debug('No employee found with ID: ' + userIdToQuery);
                return null;
            }
            
            System.debug('Employee found: ' + employees[0].Id);
            String photoUrl = employees[0].SmallPhotoUrl;
            System.debug('SmallPhotoUrl value: ' + photoUrl);
            
            if (String.isBlank(photoUrl)) {
                System.debug('SmallPhotoUrl is blank for employee');
                return null;
            }
            
            System.debug('Returning photo URL: ' + photoUrl);
            System.debug('===== END PHOTO RETRIEVAL =====');
            return photoUrl;
            
        } catch (Exception e) {
            System.debug('Error retrieving User photo: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('===== END PHOTO RETRIEVAL =====');
            return null;
        }
    }
    
    public class ConsultantData {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String photoUrl;
        @AuraEnabled
        public String phone;
        @AuraEnabled
        public Boolean hasData = false;
    }
}