/**
 * @description: Test class for SharePointFileUploadService
 * Tests file upload to SharePoint
 * @author: Fernando Hernandez
 * @created: 2026-01-05
 */
@isTest
private class SharePointFileUploadServiceTest {
    
    /**
     * Mock HTTP callout for file upload
     */
    private class MockUploadHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201); // Created
            
            String responseBody = '{' +
                '"id": "file-id-123",' +
                '"name": "testfile.pdf",' +
                '"webUrl": "https://sharepoint.com/sites/test/Documents/testfile.pdf",' +
                '"size": 1024' +
            '}';
            res.setBody(responseBody);
            
            return res;
        }
    }
    
    /**
     * Test successful file upload
     */
    @isTest
    static void testUploadFile_Success() {
        Test.setMock(HttpCalloutMock.class, new MockUploadHttpResponse());
        
        // Create test file content
        Blob fileContent = Blob.valueOf('Test file content');
        
        Test.startTest();
        SharePointFileUploadService.UploadResponse response = 
            SharePointFileUploadService.uploadFile(
                'mock-drive-id',
                'TestFolder',
                'testfile.pdf',
                fileContent,
                'mock-token'
            );
        Test.stopTest();
        
        // Verify response
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals('testfile.pdf', response.name, 'File name should match');
        System.assertEquals('https://sharepoint.com/sites/test/Documents/testfile.pdf', 
                          response.webUrl, 'WebUrl should match');
    }
    
    /**
     * Test upload with error response
     */
    @isTest
    static void testUploadFile_Error() {
        // Mock error response
        Test.setMock(HttpCalloutMock.class, new MockErrorHttpResponse());
        
        Blob fileContent = Blob.valueOf('Test file content');
        
        Test.startTest();
        try {
            SharePointFileUploadService.uploadFile(
                'mock-drive-id',
                'TestFolder',
                'testfile.pdf',
                fileContent,
                'mock-token'
            );
            System.assert(false, 'Should have thrown exception');
        } catch (SharePointFileUploadService.SharePointUploadException e) {
            System.assert(true, 'Exception should be thrown');
        }
        Test.stopTest();
    }
    
    /**
     * Mock error HTTP response
     */
    private class MockErrorHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Bad request"}}');
            return res;
        }
    }
}