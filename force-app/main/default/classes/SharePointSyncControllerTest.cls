/**
 * @description: Test class for SharePointSyncController
 * Tests LWC controller methods for SharePoint sync functionality
 * @author: Your Name
 * @created: 2026-01-05
 */
@isTest
private class SharePointSyncControllerTest {
    
    /**
     * Multi-mock HTTP callout handler
     */
    private class MockSharePointHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String endpoint = req.getEndpoint();
            
            // Mock token endpoint
            if (endpoint.contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token": "mock_token", "expires_in": 3600}');
            }
            // Mock file upload endpoint (check 'content' before /drives)
            else if (endpoint.contains('content')) {
                res.setStatusCode(201);
                res.setBody('{"id": "file-id", "name": "TestFile.pdf", "webUrl": "https://sharepoint.com/test.pdf"}');
            }
            // Mock folder children endpoint (check before /drives)
            else if (endpoint.contains('/root/children')) {
                res.setBody('{"value": [{"id": "item-001", "name": "Folder1", "folder": {"childCount": 0}}]}');
            }
            // Mock drives list endpoint — must be before /sites/ since URL contains both
            else if (endpoint.contains('/drives')) {
                res.setBody('{"value": [{"id": "mock-drive-id", "name": "Documents", "driveType": "documentLibrary"}]}');
            }
            // Mock site lookup endpoint
            else if (endpoint.contains('/sites/')) {
                res.setBody('{"id": "mock-site-id", "name": "TestSite"}');
            }
            
            return res;
        }
    }
    
    /**
     * Test data setup
     */
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test ContentVersion (file)
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test file content'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Link file to account
        ContentVersion cvInserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = cvInserted.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;

        // Create Contact with PID__c for nested folder path tests
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            PID__c = 'P12345'
        );
        insert testContact;

        // Create Benefit__c linked to the contact
        Benefit__c testBenefit = new Benefit__c(
            Member__c = testContact.Id
        );
        insert testBenefit;

        // Attach a file to the Benefit__c record
        ContentVersion benefitCv = new ContentVersion(
            Title = 'BenefitFile',
            PathOnClient = 'BenefitFile.pdf',
            VersionData = Blob.valueOf('Benefit file content'),
            IsMajorVersion = true
        );
        insert benefitCv;

        ContentVersion benefitCvInserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :benefitCv.Id];
        ContentDocumentLink benefitCdl = new ContentDocumentLink(
            LinkedEntityId = testBenefit.Id,
            ContentDocumentId = benefitCvInserted.ContentDocumentId,
            ShareType = 'V'
        );
        insert benefitCdl;
    }
    
    /**
     * Test initialize SharePoint config
     */
    @isTest
    static void testInitializeSharePointConfig() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        
        Test.startTest();
        SharePointIntegrationConfig.SharePointConfig config = 
            SharePointSyncController.initializeSharePointConfig();
        Test.stopTest();
        
        Assert.isNotNull(config, 'Config should not be null');
    }
    
    /**
     * Test get folder list
     */
    @isTest
    static void testGetFolderList() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        
        Test.startTest();
        List<String> folders = SharePointSyncController.getFolderList();
        Test.stopTest();
        
        Assert.isNotNull(folders, 'Folders should not be null');
        Assert.isFalse(folders.isEmpty(), 'Should return at least one folder');
    }
    
    /**
     * Test get synced files
     */
    @isTest
    static void testGetSyncedFiles() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        SharePoint_Sync__c syncRecord = new SharePoint_Sync__c(
            File_Name__c = 'test.pdf',
            Folder_Name__c = 'TestFolder',
            SharePoint_URL__c = 'https://sharepoint.com/test.pdf',
            Related_Record_Id__c = testAccount.Id
        );
        insert syncRecord;
        
        Test.startTest();
        List<SharePoint_Sync__c> results = 
            SharePointSyncController.getSyncedFiles(testAccount.Id, 'TestFolder');
        Test.stopTest();
        
        Assert.areEqual(1, results.size(), 'Should return 1 sync record');
        Assert.areEqual('test.pdf', results[0].File_Name__c, 'File name should match');
    }

    /**
     * Test get synced files with no folder filter
     */
    @isTest
    static void testGetSyncedFilesNoFilter() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<SharePoint_Sync__c> results =
            SharePointSyncController.getSyncedFiles(testAccount.Id, null);
        Test.stopTest();

        Assert.isNotNull(results, 'Results should not be null');
    }
    
    /**
     * Test sync files to SharePoint (flat folder, no nested structure)
     */
    @isTest
    static void testSyncFilesToSharePoint() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        String result = SharePointSyncController.syncFilesToSharePoint(
            testAccount.Id, 
            'TestFolder',
            false
        );
        Test.stopTest();
        
        Assert.isTrue(result.contains('synced'), 'Result should contain success message');
        
        List<SharePoint_Sync__c> syncRecords = [
            SELECT Id, File_Name__c, Folder_Name__c 
            FROM SharePoint_Sync__c 
            WHERE Related_Record_Id__c = :testAccount.Id
        ];
        Assert.areEqual(1, syncRecords.size(), 'Should create 1 sync record');
        Assert.areEqual('TestFolder', syncRecords[0].Folder_Name__c, 'Folder should match');
        
        List<ContentDocumentLink> remainingFiles = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testAccount.Id
        ];
        Assert.areEqual(0, remainingFiles.size(), 'Original files should be deleted after sync');
    }

    /**
     * Test sync files to SharePoint with nested folder structure
     */
    @isTest
    static void testSyncFilesToSharePointNestedFolder() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());

        Benefit__c benefit = [SELECT Id FROM Benefit__c LIMIT 1];

        Test.startTest();
        String result = SharePointSyncController.syncFilesToSharePoint(
            benefit.Id,
            'Retirement',
            true
        );
        Test.stopTest();

        Assert.isTrue(result.contains('synced'), 'Nested folder sync should succeed');

        List<SharePoint_Sync__c> syncRecords = [
            SELECT Folder_Name__c FROM SharePoint_Sync__c WHERE Related_Record_Id__c = :benefit.Id
        ];
        Assert.areEqual(1, syncRecords.size(), 'Should create 1 sync record for benefit file');
        Assert.isTrue(syncRecords[0].Folder_Name__c.contains('Employee Retirement Fund'), 'Folder path should include root folder');
        Assert.isTrue(syncRecords[0].Folder_Name__c.contains('Retirement'), 'Folder path should include base folder name');
    }

    /**
     * Test sync with no files
     */
    @isTest
    static void testSyncFilesToSharePointNoFiles() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        
        Account newAccount = new Account(Name = 'No Files Account');
        insert newAccount;
        
        Test.startTest();
        String result = SharePointSyncController.syncFilesToSharePoint(
            newAccount.Id, 
            'TestFolder',
            false
        );
        Test.stopTest();
        
        Assert.areEqual('No files found to sync', result, 'Should return no files message');
    }

    /**
     * Test buildNestedFolderPath error — record ID does not belong to a Benefit__c
     */
    @isTest
    static void testSyncNestedFolderBenefitNotFound() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());

        Account account = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            SharePointSyncController.syncFilesToSharePoint(account.Id, 'Retirement', true);
            Assert.fail('Expected AuraHandledException for missing Benefit record');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage() != null, 'Should throw for missing Benefit record');
        }
        Test.stopTest();
    }
}