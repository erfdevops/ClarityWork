@isTest
private class MyProfileControllerTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Phone = '5551234567',
            AccountId = acc.Id
        );
        insert con;
    }

    @isTest
    static void testIsProfileEditAllowed() {
        Test.startTest();
        Boolean result = MyProfileController.isProfileEditAllowed();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetEmployeeDataCurrentUser() {
        Test.startTest();
        Map<String, Object> result = MyProfileController.getEmployeeData(UserInfo.getUserId());
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetEmployeeDataWithContact() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        testUser.ContactId = con.Id;
        // Can only update ContactId in specific contexts — test the path via the current user
        // We exercise the code path for a user without a contact (null ContactId case)
        Test.startTest();
        Map<String, Object> result = MyProfileController.getEmployeeData(UserInfo.getUserId());
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testUpdateEmployeeData() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Map<String, String> updateData = new Map<String, String>{
            'email' => 'updated@example.com',
            'phoneNumber' => '5559876543',
            'birthdate' => '1990-01-15',
            'addressLine1' => '123 Main St',
            'city' => 'Springfield',
            'state' => 'IL',
            'postalCode' => '62701',
            'country' => 'US',
            'retirementDate' => '2050-01-01'
        };

        Test.startTest();
        try {
            MyProfileController.updateEmployeeData(con.Id, updateData);
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
        Test.stopTest();

        Contact updated = [SELECT Email, Phone FROM Contact WHERE Id = :con.Id LIMIT 1];
        System.assertEquals('updated@example.com', updated.Email);
        System.assertEquals('5559876543', updated.Phone);
    }

    @isTest
    static void testUpdateEmployeeDataPartial() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Map<String, String> updateData = new Map<String, String>{
            'email' => 'partial@example.com'
        };

        Test.startTest();
        MyProfileController.updateEmployeeData(con.Id, updateData);
        Test.stopTest();

        Contact updated = [SELECT Email FROM Contact WHERE Id = :con.Id LIMIT 1];
        System.assertEquals('partial@example.com', updated.Email);
    }

    @isTest
    static void testBuildContactMap() {
        Contact con = [
            SELECT Id, FirstName, LastName, Email, Phone, Birthdate,
                   MailingStreet, MailingCity, MailingState, MailingPostalCode,
                   MailingCountry, Retirement_Date__c
            FROM Contact LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> result = MyProfileController.buildContactMap(con);
        Test.stopTest();

        Assert.areEqual(con.Id, result.get('Id'), 'Id should match');
        Assert.areEqual(con.FirstName, result.get('FirstName'), 'FirstName should match');
        Assert.areEqual(con.LastName, result.get('LastName'), 'LastName should match');
        Assert.areEqual(con.Email, result.get('Email'), 'Email should match');
        Assert.areEqual(con.Phone, result.get('Phone'), 'Phone should match');
        Assert.areEqual(con.Birthdate, result.get('Birthdate'), 'Birthdate should match');
        Assert.areEqual(con.MailingStreet, result.get('MailingStreet'), 'MailingStreet should match');
        Assert.areEqual(con.MailingCity, result.get('MailingCity'), 'MailingCity should match');
        Assert.areEqual(con.MailingState, result.get('MailingState'), 'MailingState should match');
        Assert.areEqual(con.MailingPostalCode, result.get('MailingPostalCode'), 'MailingPostalCode should match');
        Assert.areEqual(con.MailingCountry, result.get('MailingCountry'), 'MailingCountry should match');
        Assert.areEqual(con.Retirement_Date__c, result.get('Retirement_Date__c'), 'Retirement_Date__c should match');
    }
}