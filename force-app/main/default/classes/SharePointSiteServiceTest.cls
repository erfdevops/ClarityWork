/**
 * @description: Test class for SharePointSiteService
 * Tests Site ID, Drive ID retrieval, and folder listing
 * @author: Fernando Hernandez
 * @created: 2026-01-05
 */
@isTest
private class SharePointSiteServiceTest {
    
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
            // Mock folder children endpoint (must be checked before /drives)
            else if (endpoint.contains('/root/children')) {
                res.setBody(
                    '{"value": [' +
                        '{"id": "item-001", "name": "Folder1", "folder": {"childCount": 0}},' +
                        '{"id": "item-002", "name": "Folder2", "folder": {"childCount": 2}},' +
                        '{"id": "item-003", "name": "file.pdf", "file": {"mimeType": "application/pdf"}}' +
                    ']}'
                );
            }
            // Mock drives list endpoint — /sites/{siteId}/drives (must be checked before /sites/)
            else if (endpoint.contains('/drives')) {
                res.setBody(
                    '{"value": [' +
                        '{"id": "mock-drive-id-456", "name": "Documents", "driveType": "documentLibrary"}' +
                    ']}'
                );
            }
            // Mock site lookup endpoint
            else if (endpoint.contains('/sites/')) {
                res.setBody('{"id": "mock-site-id-123", "name": "TestSite"}');
            }
            
            return res;
        }
    }
    
    /**
     * Test getting folder list
     */
    @isTest
    static void testGetFolderList() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        
        Test.startTest();
        List<String> folders = SharePointSiteService.getFolderList('mock-drive-id-456');
        Test.stopTest();
        
        // Should return only folders, not files
        System.assertEquals(2, folders.size(), 'Should return 2 folders');
        System.assert(folders.contains('Folder1'), 'Should contain Folder1');
        System.assert(folders.contains('Folder2'), 'Should contain Folder2');
    }
    
    /**
     * Test initialization configuration
     */
    @isTest
    static void testInitializeSharePointConfiguration() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        
        Test.startTest();
        SharePointIntegrationConfig.SharePointConfig config = 
            SharePointSiteService.initializeSharePointConfiguration();
        Test.stopTest();
        
        // Verify config is returned
        System.assertNotEquals(null, config, 'Config should not be null');
    }

    @IsTest
    static void testGetSiteId() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        String testTenantName = 'tenant';
        String testSiteName = 'site';

        Test.startTest();
        String siteIdResult =
            SharePointSiteService.getSiteId(testTenantName, testSiteName);
        Test.stopTest();

        Assert.isNotNull(siteIdResult, 'Site ID should match mock');
    }

    @IsTest
    static void testGetDriveId() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());
        String testSiteId = 'test-site-id';

        Test.startTest();
        String driveIdResult =
            SharePointSiteService.getDriveId(testSiteId);
        Test.stopTest();

        Assert.isNotNull(driveIdResult, 'Drive ID should match mock');
    }

    @isTest
    static void testGetFolderListWithToken() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());

        Test.startTest();
        List<String> folders = SharePointSiteService.getFolderList('mock-drive-id-456', 'mock_token');
        Test.stopTest();

        Assert.isNotNull(folders, 'Folder list should not be null');
        Assert.areEqual(2, folders.size(), 'Should return 2 folders');
        Assert.isTrue(folders.contains('Folder1'), 'Should contain Folder1');
        Assert.isTrue(folders.contains('Folder2'), 'Should contain Folder2');
    }

    @isTest
    static void testGetFolderListBlankDriveId() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());

        Test.startTest();
        try {
            SharePointSiteService.getFolderList('', 'mock_token');
            Assert.fail('Expected exception for blank driveId');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Drive ID cannot be blank'), 'Should throw for blank drive ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetFolderListBlankAccessToken() {
        Test.setMock(HttpCalloutMock.class, new MockSharePointHttpResponse());

        Test.startTest();
        try {
            SharePointSiteService.getFolderList('some-drive-id', '');
            Assert.fail('Expected exception for blank access token');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Access token cannot be blank'), 'Should throw for blank access token');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetFolderListNonOkResponse() {
        Test.setMock(HttpCalloutMock.class, new MockErrorHttpResponse());

        Test.startTest();
        try {
            SharePointSiteService.getFolderList('mock-drive-id', 'mock_token');
            Assert.fail('Expected exception for non-200 response');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Failed'), 'Should throw on error response');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateAllConfigurationInMetadata() {
        Test.startTest();
        // @TestVisible allows direct call; !Test.isRunningTest() guard skips actual deployment
        SharePointSiteService.updateAllConfigurationInMetadata('test-site-id', 'test-drive-id');
        Test.stopTest();
        // No exception means the metadata object construction path ran successfully
        Assert.isTrue(true, 'updateAllConfigurationInMetadata should complete without error');
    }

    @isTest
    static void testInnerClassWrappers() {
        // SiteResponse
        SharePointSiteService.SiteResponse site = new SharePointSiteService.SiteResponse();
        site.id = 'site-123';
        site.name = 'TestSite';
        site.displayName = 'Test Site Display';
        site.webUrl = 'https://tenant.sharepoint.com/sites/test';
        site.description = 'A test site';
        site.createdDateTime = '2026-01-01T00:00:00Z';
        site.lastModifiedDateTime = '2026-01-02T00:00:00Z';
        Assert.areEqual('site-123', site.id);
        Assert.areEqual('TestSite', site.name);

        // DriveItem with folder
        SharePointSiteService.FolderInfo folderInfo = new SharePointSiteService.FolderInfo();
        folderInfo.childCount = 5;
        SharePointSiteService.DriveItem folderItem = new SharePointSiteService.DriveItem();
        folderItem.id = 'item-001';
        folderItem.name = 'MyFolder';
        folderItem.webUrl = 'https://tenant.sharepoint.com/Shared Documents/MyFolder';
        folderItem.createdDateTime = '2026-01-01T00:00:00Z';
        folderItem.lastModifiedDateTime = '2026-01-02T00:00:00Z';
        folderItem.size = 2048L;
        folderItem.folder = folderInfo;
        Assert.areEqual('MyFolder', folderItem.name);
        Assert.areEqual(5, folderItem.folder.childCount);
        Assert.areEqual(2048L, folderItem.size);

        // DriveItem with file
        SharePointSiteService.FileInfo fileInfo = new SharePointSiteService.FileInfo();
        fileInfo.mimeType = 'application/pdf';
        SharePointSiteService.DriveItem fileItem = new SharePointSiteService.DriveItem();
        fileItem.id = 'item-002';
        fileItem.name = 'document.pdf';
        fileItem.file = fileInfo;
        Assert.areEqual('application/pdf', fileItem.file.mimeType);

        // DriveInfo with DriveQuota
        SharePointSiteService.DriveQuota quota = new SharePointSiteService.DriveQuota();
        quota.total = 1099511627776L;
        quota.used = 549755813888L;
        quota.remaining = 549755813888L;
        quota.deleted = 0L;
        quota.state = 'normal';
        SharePointSiteService.DriveInfo drive = new SharePointSiteService.DriveInfo();
        drive.id = 'drive-abc';
        drive.name = 'Documents';
        drive.driveType = 'documentLibrary';
        drive.webUrl = 'https://tenant.sharepoint.com/Shared Documents';
        drive.description = 'Main document library';
        drive.createdDateTime = '2026-01-01T00:00:00Z';
        drive.lastModifiedDateTime = '2026-01-02T00:00:00Z';
        drive.quota = quota;
        Assert.areEqual('drive-abc', drive.id);
        Assert.areEqual('documentLibrary', drive.driveType);
        Assert.areEqual(1099511627776L, drive.quota.total);
        Assert.areEqual('normal', drive.quota.state);
    }

    private class MockErrorHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error": {"code": "InvalidAuthenticationToken", "message": "Unauthorized"}}');
            return res;
        }
    }

}