/**
 * @description: SharePoint File Upload Service
 * Handles uploading files from Salesforce to SharePoint
 * @author: Fernando Hernandez
 * @created: 2026-01-05
 */
public without sharing class SharePointFileUploadService {
    
    private static final String GRAPH_API_ENDPOINT = 'https://graph.microsoft.com/v1.0';
    
    /**
     * @description: Upload a file to SharePoint
     * @param driveId: The SharePoint Drive ID
     * @param folderName: The folder name where to upload
     * @param fileName: The name of the file
     * @param fileContent: The file content as Blob
     * @param accessToken: The OAuth access token
     * @return: Upload response with webUrl and name
     */
    public static UploadResponse uploadFile(String driveId, String folderName, String fileName, Blob fileContent, String accessToken) {
        try {
            System.debug('Uploading file to SharePoint: ' + fileName);
            System.debug('Folder: ' + folderName);
            System.debug('File size: ' + fileContent.size() + ' bytes');
            
            // Encode folder path and file name for URL
            // Replace + with %20 for proper space encoding in SharePoint paths
            String encodedFolderPath = EncodingUtil.urlEncode(folderName, 'UTF-8').replace('+', '%20');
            String encodedFileName = EncodingUtil.urlEncode(fileName, 'UTF-8').replace('+', '%20');
            
            // Build the endpoint: /drives/{driveId}/root:/{folderName}/{fileName}:/content
            String endpoint = GRAPH_API_ENDPOINT + '/drives/' + driveId + '/root:/' + 
                            encodedFolderPath + '/' + 
                            encodedFileName + ':/content';
            
            System.debug('Upload endpoint: ' + endpoint);
            
            // Create HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('PUT');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/octet-stream');
            req.setBodyAsBlob(fileContent);
            req.setTimeout(120000); // 2 minutes timeout for large files
            
            // Send request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Upload response status: ' + res.getStatusCode());
            System.debug('Upload response body: ' + res.getBody());
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                // Parse response
                UploadResponse uploadResponse = (UploadResponse) JSON.deserialize(res.getBody(), UploadResponse.class);
                System.debug('✅ File uploaded successfully');
                System.debug('WebUrl: ' + uploadResponse.webUrl);
                System.debug('Name: ' + uploadResponse.name);
                
                return uploadResponse;
            } else {
                throw new SharePointUploadException(
                    'Upload failed with status ' + res.getStatusCode() + ': ' + res.getBody()
                );
            }
            
        } catch (Exception e) {
            System.debug('❌ Error uploading file: ' + e.getMessage());
            throw new SharePointUploadException('Failed to upload file: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper class for SharePoint upload response
     * Captures the important fields from the Graph API response
     */
    public class UploadResponse {
        public String id { get; set; }
        public String name { get; set; }
        public String webUrl { get; set; }
        public Long size { get; set; }
        public String createdDateTime { get; set; }
        public String lastModifiedDateTime { get; set; }
    }
    
    /**
     * Custom exception for upload errors
     */
    public class SharePointUploadException extends Exception {}
}