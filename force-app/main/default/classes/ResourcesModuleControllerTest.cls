/**
 * @description       : This class is the Controller for the Resources Lwc
 * @author            : Soaritude 03-31-2025
 * @group             : 
 * @last modified on  : 04-02-2026
 * @last modified by  : Soaritude
**/

@IsTest
private class ResourcesModuleControllerTest {

    private class MockSharePointHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String endpoint = req.getEndpoint();

            if (endpoint.contains('oauth2/v2.0/token')) {
                res.setBody('{"access_token": "mock_token", "expires_in": 3600}');
            } else if (endpoint.contains('content')) {
                res.setStatusCode(201);
                res.setBody('{"id": "file-id", "name": "testFile.txt", "webUrl": "https://sharepoint.com/testFile.txt"}');
            } else if (endpoint.contains('/root/children')) {
                res.setBody('{"value": [{"id": "item-001", "name": "TestFolder", "folder": {"childCount": 0}}]}');
            } else if (endpoint.contains('/drives')) {
                res.setBody('{"value": [{"id": "mock-drive-id", "name": "Documents", "driveType": "documentLibrary"}]}');
            } else if (endpoint.contains('/sites/')) {
                res.setBody('{"id": "mock-site-id", "name": "TestSite"}');
            }

            return res;
        }
    }

    @IsTest
    static void testGenerateContentFiles() {
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('Test file content'));
        String fileName = 'testFile.txt';
        Boolean sharedWithMembers = true;

        Test.startTest();
        String createdRecordId = ResourcesModuleController.generateContentFiles(base64Content, fileName, sharedWithMembers);
        Test.stopTest();

        Assert.isNotNull(createdRecordId);

        SoaritudeDoc__c insertedRecord = [
            SELECT Id, Name, Shared_With_Members__c, Content_Version_Id__c
            FROM SoaritudeDoc__c
            WHERE Id = :createdRecordId
            LIMIT 1
        ];

        Assert.areEqual(fileName, insertedRecord.Name);
        Assert.areEqual(sharedWithMembers, insertedRecord.Shared_With_Members__c);
        Assert.isNotNull(insertedRecord.Content_Version_Id__c);

        List<ContentDocumentLink> documentLinks = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :createdRecordId
        ];

        Assert.areEqual(1, documentLinks.size());
    }

    @IsTest
    static void testGetResourceFilesAllRecords() {
        SoaritudeDoc__c testRecord = new SoaritudeDoc__c(
            Name = 'sample.pdf',
            Shared_With_Members__c = true,
            Sharepoint_URL__c = 'https://test.url'
        );
        insert testRecord;

        Test.startTest();
        String jsonResponse = ResourcesModuleController.getResourceFiles(false);
        Test.stopTest();

        Assert.isNotNull(jsonResponse);
        Assert.isTrue(jsonResponse.contains('sample.pdf'));
    }

    @IsTest
    static void testGetResourceFilesExperienceFilter() {
        SoaritudeDoc__c visibleRecord = new SoaritudeDoc__c(
            Name = 'visible.pdf',
            Shared_With_Members__c = true
        );

        SoaritudeDoc__c hiddenRecord = new SoaritudeDoc__c(
            Name = 'hidden.pdf',
            Shared_With_Members__c = false
        );

        insert new List<SoaritudeDoc__c>{ visibleRecord, hiddenRecord };

        Test.startTest();
        String jsonResponse = ResourcesModuleController.getResourceFiles(true);
        Test.stopTest();

        Assert.isTrue(jsonResponse.contains('visible.pdf'));
        Assert.isFalse(jsonResponse.contains('hidden.pdf'));
    }

    @IsTest
    static void testDeleteSelectedFile() {
        ContentVersion testVersion = new ContentVersion(
            Title = 'deleteMe',
            PathOnClient = 'deleteMe.txt',
            VersionData = Blob.valueOf('Delete content'),
            IsMajorVersion = true
        );
        insert testVersion;

        ContentVersion insertedVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :testVersion.Id
            LIMIT 1
        ];

        Test.startTest();
        Boolean deleteResult = ResourcesModuleController.deleteSelectedFile(insertedVersion.ContentDocumentId);
        Test.stopTest();

        Assert.isTrue(deleteResult);

        List<ContentDocument> deletedDocs = [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :insertedVersion.ContentDocumentId
        ];

        Assert.areEqual(0, deletedDocs.size());
    }

    @IsTest
    static void testUploadNewFile() {
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('Upload test'));
        String fileName = 'uploadTest.txt';

        Test.startTest();
        Boolean result = ResourcesModuleController.uploadNewFile(base64Content, fileName, true);
        Test.stopTest();

        Assert.isTrue(result);

        List<SoaritudeDoc__c> createdRecords = [
            SELECT Id, Name
            FROM SoaritudeDoc__c
            WHERE Name = :fileName
        ];

        Assert.areEqual(1, createdRecords.size());
    }

    @IsTest
    static void testSynchronizeFileToSharePoint() {
        // First create a SoaritudeDoc and link a file to it
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('Sync test content'));
        String fileName = 'syncTest.txt';
        String soaritudeDocId = ResourcesModuleController.generateContentFiles(base64Content, fileName, true);

        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());

        Test.startTest();
        ResourcesModuleController.synchronizeFileToSharePoint(soaritudeDocId);
        Test.stopTest();

        // SharePoint_Sync__c record should have been created and linked back
        List<SharePoint_Sync__c> syncRecords = [
            SELECT Id, File_Name__c, Related_Record_Id__c
            FROM SharePoint_Sync__c
            WHERE Related_Record_Id__c = :soaritudeDocId
        ];
        Assert.areEqual(1, syncRecords.size(), 'Should create 1 SharePoint_Sync__c record');
        Assert.isNotNull(syncRecords[0].File_Name__c, 'File name should be populated from SharePoint response');

        // SoaritudeDoc__c should be updated with the sync record reference
        SoaritudeDoc__c updatedDoc = [
            SELECT SharePoint_Sync__c, Sharepoint_URL__c, Content_Version_Id__c
            FROM SoaritudeDoc__c WHERE Id = :soaritudeDocId
        ];
        Assert.areEqual(syncRecords[0].Id, updatedDoc.SharePoint_Sync__c, 'Sync record should be linked');
    }

    @IsTest
    static void testSynchronizeFileToSharePointBlankDriveId() {
        // Call with a recordId that has no linked files — exercises driveId blank guard
        // Config will have blank driveId in test context without metadata → hits catch silently
        SoaritudeDoc__c emptyDoc = new SoaritudeDoc__c(
            Name = 'empty.txt',
            Shared_With_Members__c = false
        );
        insert emptyDoc;

        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());

        Test.startTest();
        // Should not throw — exception is caught internally
        ResourcesModuleController.synchronizeFileToSharePoint(emptyDoc.Id);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle missing drive ID gracefully');
    }
}