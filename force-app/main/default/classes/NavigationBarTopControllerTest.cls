@IsTest
private class NavigationBarTopControllerTest {

    @IsTest
    static void testIsUserMemberWithMemberRecordType() {
        Profile systemAdministratorProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        UserRole systemAdministratorRole = [SELECT Id FROM UserRole WHERE Name = 'Technology Leadership Team' LIMIT 1];

        User consultantUser = new User(
            FirstName = 'Consultant',
            LastName = 'User',
            Email = 'consultantuser@test.com',
            Username = 'consultantuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'cuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = systemAdministratorProfile.Id,
            UserRoleId = systemAdministratorRole.Id
        );
        insert consultantUser;


        System.runas(consultantUser) {
            Profile customerCommunityPlusProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1];
            String memberRecordTypeId = Schema.getGlobalDescribe().get('Contact').getDescribe().getRecordTypeInfosByName().get('Member').getRecordTypeId();

            Account memberAccount = new Account(
                Name = 'Test Account'
            );
            insert memberAccount;

            Contact memberContact = new Contact(
                LastName = 'Member Contact',
                RecordTypeId = memberRecordTypeId,
                AccountId = memberAccount.Id
            );
            insert memberContact;

            User portalUser = new User(
                FirstName = 'Portal',
                LastName = 'User',
                Email = 'portaluser@test.com',
                Username = 'portaluser' + System.currentTimeMillis() + '@test.com',
                Alias = 'puser',
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = customerCommunityPlusProfile.Id,
                ContactId = memberContact.Id
            );
            insert portalUser;

            System.runAs(portalUser) {
                Boolean isMemberResult = NavigationBarTopController.isUserMember();
                Assert.isTrue(isMemberResult, 'Expected user to be recognized as member');
            }
        }
    }

    @IsTest
    static void testIsUserMemberWithoutContact() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User userWithoutContact = new User(
            FirstName = 'No',
            LastName = 'Contact',
            Email = 'nocontact@test.com',
            Username = 'nocontact' + System.currentTimeMillis() + '@test.com',
            Alias = 'ncusr',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id
        );
        insert userWithoutContact;

        System.runAs(userWithoutContact) {
            Boolean isMemberResult = NavigationBarTopController.isUserMember();
            Assert.isFalse(isMemberResult, 'Expected user without contact to not be member');
        }
    }

    @IsTest
    static void testGetConsultantDataWithConsultant() {
        Profile systemAdministratorProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        UserRole systemAdministratorRole = [SELECT Id FROM UserRole WHERE Name = 'Technology Leadership Team' LIMIT 1];

        User consultantUser = new User(
            FirstName = 'Consultant',
            LastName = 'Assigned',
            Email = 'assignedconsultant@test.com',
            Phone = '123456789',
            Username = 'assignedconsultant' + System.currentTimeMillis() + '@test.com',
            Alias = 'acons',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = systemAdministratorProfile.Id,
            UserRoleId = systemAdministratorRole.Id
        );
        insert consultantUser;

        System.runas(consultantUser) {
            Profile customerCommunityPlusProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1];
            PermissionSet customerCommunityPlusPermissionSet = [SELECT Id FROM PermissionSet WHERE Name = 'LMS_Learner'];

            Employee__c employeeConsultant = new Employee__c(
                Name = 'Test Consultant',
                Employee_Name__c = 'Test Consultant',
                Phone__c = '1234567890',
                User__c = consultantUser.Id
            );
            insert employeeConsultant;

            Account testAccount = new Account(
                Name = 'Test Account'
            );
            insert testAccount;

            Contact contactMember = new Contact(
                LastName = 'Member Contact',
                Retire_Now_Consultant__c = employeeConsultant.Id,
                AccountId = testAccount.Id
            );
            insert contactMember;

            User portalUser = new User(
                FirstName = 'Portal',
                LastName = 'User',
                Email = 'portalconsultant@test.com',
                Username = 'portalconsultant' + System.currentTimeMillis() + '@test.com',
                Alias = 'pcons',
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = customerCommunityPlusProfile.Id,
                ContactId = contactMember.Id
            );
            insert portalUser;

            List<PermissionSetAssignment> permissionSetCheck = [
                SELECT Id, AssigneeId, PermissionSetId 
                FROM PermissionSetAssignment 
                WHERE AssigneeId = :portalUser.Id 
                AND PermissionSetId = :customerCommunityPlusPermissionSet.Id
            ];

            if (permissionSetCheck.size() == 0) {
                insert new PermissionSetAssignment(AssigneeId = portalUser.Id, PermissionSetId = customerCommunityPlusPermissionSet.Id);
            }
            
            System.runAs(portalUser) {
                NavigationBarTopController.ConsultantData consultantDataResult = NavigationBarTopController.getConsultantData();
                Assert.isTrue(consultantDataResult.hasData, 'Expected consultant data to be present');
                Assert.areEqual(employeeConsultant.Name, consultantDataResult.name, 'Consultant name mismatch');
                Assert.areEqual(employeeConsultant.Phone__c, consultantDataResult.phone, 'Consultant phone mismatch');
            }
        }
    }

    @IsTest
    static void testGetConsultantDataWithoutConsultant() {
        Profile systemAdministratorProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        UserRole systemAdministratorRole = [SELECT Id FROM UserRole WHERE Name = 'Technology Leadership Team' LIMIT 1];

        User consultantUser = new User(
            FirstName = 'Consultant',
            LastName = 'Assigned',
            Email = 'assignedconsultant@test.com',
            Username = 'assignedconsultant' + System.currentTimeMillis() + '@test.com',
            Alias = 'acons',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = systemAdministratorProfile.Id,
            UserRoleId = systemAdministratorRole.Id
        );
        insert consultantUser;

        System.runas(consultantUser) {
            Profile customerCommunityPlusProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1];

            Account testAccount = new Account(
                Name = 'Test Account'
            );
            insert testAccount;

            Contact contactWithoutConsultant = new Contact(
                LastName = 'No Consultant',
                AccountId = testAccount.Id
            );
            insert contactWithoutConsultant;

            User portalUser = new User(
                FirstName = 'Portal',
                LastName = 'User',
                Email = 'portalnoconsultant@test.com',
                Username = 'portalnoconsultant' + System.currentTimeMillis() + '@test.com',
                Alias = 'pncon',
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = customerCommunityPlusProfile.Id,
                ContactId = contactWithoutConsultant.Id
            );
            insert portalUser;

            System.runAs(portalUser) {
                NavigationBarTopController.ConsultantData consultantDataResult = NavigationBarTopController.getConsultantData();
                Assert.isFalse(consultantDataResult.hasData, 'Expected no consultant data');
            }
        }
    }
}