/**
 * @description       : This class is the Unit Test for DocumentsModuleController class
 * @author            : Pablo Castro 02-17-2026
 * @group             : 
 * @last modified on  : 04-06-2026
 * @last modified by  : Pablo Castro
**/

@isTest
private class DocumentsModuleControllerTest {

    @isTest
    static void testUploadNewFileOnSuccess() {
        Contact testContact = new Contact(LastName = 'Test Contact');
        insert testContact;

        Benefit__c testBenefitRecord = new Benefit__c(
            Benefit_Name__c = 'Test Benefit Name',
            Member__c = testContact.Id
        );
        insert testBenefitRecord;

        String testFileName = 'TestFile.txt';
        String base64FileContent = EncodingUtil.base64Encode(Blob.valueOf('Sample file content'));

        Test.startTest();
        Boolean firstUploadResult = DocumentsModuleController.uploadNewFile(
            testBenefitRecord.Id,
            base64FileContent,
            testFileName
        );
        Test.stopTest();

        Assert.isTrue(firstUploadResult, 'First file upload should succeed');
    }

    @isTest
    static void testDuplicateFileUploadHandling() {
        Contact testContact = new Contact(LastName = 'Test Contact');
        insert testContact;

        Benefit__c testBenefitRecord = new Benefit__c(
            Benefit_Name__c = 'Test Benefit Name',
            Member__c = testContact.Id
        );
        insert testBenefitRecord;

        String testFileName = 'TestFile.txt';
        String base64FileContent = EncodingUtil.base64Encode(Blob.valueOf('Sample file content'));

        Test.startTest();
        Boolean secondUploadResult = DocumentsModuleController.uploadNewFile(
            testBenefitRecord.Id,
            base64FileContent,
            testFileName
        );
        Test.stopTest();

        Assert.isTrue(secondUploadResult, 'Second file upload should succeed and handle duplicates');

        List<ContentDocumentLink> linkedFiles = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testBenefitRecord.Id
        ];

        Assert.areEqual(1, linkedFiles.size(), 'Only one file should remain after duplicate handling');
    }

    @isTest
    static void testGetFilesRelatedToUserWithFiles() {
        Profile systemAdministratorProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        UserRole systemAdministratorRole = [SELECT Id FROM UserRole WHERE Name = 'Technology Leadership Team' LIMIT 1];
        Profile testUserRole = [SELECT Id, Name FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1];
        String jsonResponse = '';

        User sysAdminUser = new User(
            FirstName = 'SysAdmin',
            LastName = 'TestUser',
            Email = 'sysadmintestuser@test.com',
            Username = 'sysadmintestuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'sysadm',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = systemAdministratorProfile.Id,
            UserRoleId = systemAdministratorRole.Id
        );
        insert sysAdminUser;

        System.runAs(sysAdminUser) {
            Account testAccount = new Account(
                Name = 'TestAccountName',
                OwnerId = sysAdminUser.Id
            );
            insert testAccount;

            Contact testContact = new Contact(
                FirstName = 'FirstNameTest',
                LastName = 'LastNameTest',
                AccountId = testAccount.Id,
                OwnerId = sysAdminUser.Id
            );
            insert testContact;

            User testUser = new User(
                Alias = 'tuser',
                Email = 'testuser@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = testUserRole.Id,
                TimeZoneSidKey = 'America/New_York',
                Username = 'testuser' + System.currentTimeMillis() + '@example.com',
                ContactId = testContact.Id
            );
            insert testUser;

            Benefit__c testBenefitRecord = new Benefit__c(
                Benefit_Name__c = 'Benefit Name',
                Member__c = testContact.Id
            );
            insert testBenefitRecord;

            String base64FileContent = EncodingUtil.base64Encode(Blob.valueOf('File content'));
            DocumentsModuleController.uploadNewFile(
                testBenefitRecord.Id,
                base64FileContent,
                'UserFile.txt'
            );

            Test.startTest();
                jsonResponse = DocumentsModuleController.getFilesRelatedToUser(testUser.Id);
            Test.stopTest();

            }

            Assert.isNotNull(jsonResponse, 'JSON response should not be null');
            Assert.isTrue(jsonResponse.contains('UserFile.txt'), 'Response should contain uploaded file name');
        }

    @isTest
    static void testGetFilesRelatedToUserNoContact() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUserWithoutContact = new User(
            Alias = 'nocon',
            Email = 'nocontact@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NoContact',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'nocontact' + System.currentTimeMillis() + '@example.com'
        );
        insert testUserWithoutContact;

        Test.startTest();
        String jsonResponse = DocumentsModuleController.getFilesRelatedToUser(testUserWithoutContact.Id);
        Test.stopTest();

        Assert.isTrue(
            jsonResponse.contains('There is no Contact record associated to this User'),
            'Should return error message when no contact is linked'
        );
    }

    @isTest
    static void testDeleteSelectedFileOnSuccess() {
        Contact testContact = new Contact(LastName = 'Delete Contact');
        insert testContact;

        Benefit__c testBenefitRecord = new Benefit__c(
            Benefit_Name__c = 'Delete Benefit Name',
            Member__c = testContact.Id
        );
        insert testBenefitRecord;

        String base64FileContent = EncodingUtil.base64Encode(Blob.valueOf('Delete me'));
        DocumentsModuleController.uploadNewFile(
            testBenefitRecord.Id,
            base64FileContent,
            'DeleteFile.txt'
        );

        ContentDocumentLink linkedFile = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testBenefitRecord.Id
            LIMIT 1
        ];

        Test.startTest();
        Boolean deleteResult = DocumentsModuleController.deleteSelectedFile(linkedFile.ContentDocumentId);
        Test.stopTest();

        Assert.isTrue(deleteResult, 'File deletion should succeed');

        List<ContentDocument> deletedDocuments = [
            SELECT Id FROM ContentDocument WHERE Id = :linkedFile.ContentDocumentId
        ];

        Assert.areEqual(0, deletedDocuments.size(), 'File should be deleted from ContentDocument');
    }
}