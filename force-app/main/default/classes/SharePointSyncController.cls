/**
 * @description: Controller for SharePoint File Sync LWC
 * Handles initialization, folder retrieval, and file syncing operations
 * @author: Fernando Hernandez
 * @created: 2026-01-05
 */
public without sharing class SharePointSyncController {
    
    /**
     * @description: Initialize SharePoint configuration
     * Called when the LWC component loads
     * @return: SharePoint configuration with all required IDs
     */
    @AuraEnabled(cacheable=false)
    public static SharePointIntegrationConfig.SharePointConfig initializeSharePointConfig() {
        try {
            System.debug('SharePointSyncController: Initializing configuration');
            SharePointIntegrationConfig.SharePointConfig config = SharePointSiteService.initializeSharePointConfiguration();
            System.debug('SharePointSyncController: Configuration initialized successfully');
            return config;
        } catch (Exception e) {
            System.debug('SharePointSyncController: Error initializing config - ' + e.getMessage());
            throw new AuraHandledException('Failed to initialize SharePoint configuration: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Get list of folders from SharePoint drive
     * @return: List of folder names for dropdown
     */
    @AuraEnabled(cacheable=false)
    public static List<String> getFolderList() {
        try {
            System.debug('SharePointSyncController: Getting folder list');
            
            // Get configuration
            SharePointIntegrationConfig.SharePointConfig config = SharePointIntegrationConfig.getConfig();
            
            if (String.isBlank(config.driveId)) {
                throw new AuraHandledException('Drive ID not found in configuration');
            }
            
            // Get cached access token
            String accessToken = SharePointAuthService.getAccessToken();
            
            if (String.isBlank(accessToken)) {
                throw new AuraHandledException('Failed to obtain access token');
            }
            
            // Get folder list using both parameters to avoid uncommitted work errors
            List<String> folders = SharePointSiteService.getFolderList(config.driveId, accessToken);
            System.debug('SharePointSyncController: Retrieved ' + folders.size() + ' folders');
            
            return folders;
            
        } catch (Exception e) {
            System.debug('SharePointSyncController: Error getting folders - ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve folder list: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Get synced files for a specific record
     * Optionally filter by folder name
     * @param recordId: The Salesforce record ID
     * @param folderName: Optional folder name to filter by
     * @return: List of SharePoint_Sync__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<SharePoint_Sync__c> getSyncedFiles(String recordId, String folderName) {
        try {
            System.debug('SharePointSyncController: Getting synced files for record: ' + recordId);
            
            String query = 'SELECT Id, Name, File_Name__c, Folder_Name__c, SharePoint_URL__c ' +
                          'FROM SharePoint_Sync__c ' +
                          'WHERE Related_Record_Id__c = :recordId';
            
            
            
            query += ' ORDER BY CreatedDate DESC';
            
            List<SharePoint_Sync__c> syncedFiles = Database.query(query);
            System.debug('SharePointSyncController: Found ' + syncedFiles.size() + ' synced files');
            
            return syncedFiles;
            
        } catch (Exception e) {
            System.debug('SharePointSyncController: Error getting synced files - ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve synced files: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Sync files from Salesforce to SharePoint
     * Uploads all files related to a record to SharePoint, creates sync records, and deletes originals
     * @param recordId: The Salesforce record ID
     * @param folderName: The SharePoint folder name to upload to
     * @param useNestedFolderStructure: Whether to use nested folder structure (Employee Retirement Fund/folderName/Name - PID__c)
     * @return: Success message with count of files synced
     */
    @AuraEnabled
    public static String syncFilesToSharePoint(String recordId, String folderName, Boolean useNestedFolderStructure) {
        try {
            System.debug('SharePointSyncController: Syncing files for record: ' + recordId + ' to folder: ' + folderName);
            System.debug('Use nested folder structure: ' + useNestedFolderStructure);
            
            // Determine the final folder path
            String finalFolderPath = folderName;
            
            if (useNestedFolderStructure != null && useNestedFolderStructure) {
                finalFolderPath = buildNestedFolderPath(recordId, folderName);
                System.debug('Using nested folder path: ' + finalFolderPath);
            }
            
            // Step 1: Get configuration and access token
            SharePointIntegrationConfig.SharePointConfig config = SharePointIntegrationConfig.getConfig();
            String accessToken = SharePointAuthService.getAccessToken();
            
            if (String.isBlank(config.driveId)) {
                throw new AuraHandledException('Drive ID not configured');
            }
            
            if (String.isBlank(accessToken)) {
                throw new AuraHandledException('Failed to obtain access token');
            }
            
            // Step 2: Query files related to the record
            List<ContentDocumentLink> fileLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                       ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
            ];
            
            if (fileLinks.isEmpty()) {
                return 'No files found to sync';
            }
            
            System.debug('Found ' + fileLinks.size() + ' files to sync');
            
            // Step 3: Get file content for each file
            Set<Id> versionIds = new Set<Id>();
            for (ContentDocumentLink link : fileLinks) {
                versionIds.add(link.ContentDocument.LatestPublishedVersionId);
            }
            
            Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>([
                SELECT Id, ContentDocumentId, VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE Id IN :versionIds
            ]);
            
            // Step 4: Upload each file to SharePoint
            List<SharePoint_Sync__c> syncRecords = new List<SharePoint_Sync__c>();
            List<Id> documentsToDelete = new List<Id>();
            Integer successCount = 0;
            
            for (ContentDocumentLink link : fileLinks) {
                try {
                    ContentVersion version = versionMap.get(link.ContentDocument.LatestPublishedVersionId);
                    
                    if (version == null) {
                        System.debug('⚠️ Version not found for document: ' + link.ContentDocumentId);
                        continue;
                    }
                    
                    String fileName = version.Title + '.' + version.FileExtension;
                    Blob fileContent = version.VersionData;
                    
                    System.debug('Uploading file: ' + fileName);
                    
                    // Upload to SharePoint
                    SharePointFileUploadService.UploadResponse uploadResponse = 
                        SharePointFileUploadService.uploadFile(
                            config.driveId,
                            finalFolderPath,
                            fileName,
                            fileContent,
                            accessToken
                        );
                    
                    // Create SharePoint Sync record
                    SharePoint_Sync__c syncRecord = new SharePoint_Sync__c(
                        File_Name__c = uploadResponse.name,
                        Folder_Name__c = finalFolderPath,
                        SharePoint_URL__c = uploadResponse.webUrl,
                        Related_Record_Id__c = recordId
                    );
                    syncRecords.add(syncRecord);
                    
                    // Mark document for deletion
                    documentsToDelete.add(link.ContentDocumentId);
                    
                    successCount++;
                    System.debug('✅ File uploaded successfully: ' + fileName);
                    
                } catch (Exception fileError) {
                    System.debug('❌ Error uploading file: ' + fileError.getMessage());
                    // Continue with next file even if one fails
                }
            }
            
            // Step 5: Insert SharePoint Sync records
            if (!syncRecords.isEmpty()) {
                insert syncRecords;
                System.debug('Created ' + syncRecords.size() + ' SharePoint Sync records');
            }
            
            // Step 6: Delete original Salesforce files
            if (!documentsToDelete.isEmpty()) {
                List<ContentDocument> docsToDelete = [
                    SELECT Id FROM ContentDocument WHERE Id IN :documentsToDelete
                ];
                delete docsToDelete;
                System.debug('Deleted ' + docsToDelete.size() + ' original files from Salesforce');
            }
            
            String resultMessage = successCount + ' file(s) synced to SharePoint successfully';
            System.debug('✅ Sync complete: ' + resultMessage);
            
            return resultMessage;
            
        } catch (Exception e) {
            System.debug('SharePointSyncController: Error syncing files - ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to sync files: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Build nested folder path for object-specific configuration
     * Format: Employee Retirement Fund/{baseFolderName}/{ContactName - PID}
     * @param recordId: The Benefit__c record ID
     * @param baseFolderName: The base folder name from component configuration
     * @return: Full folder path string
     */
    private static String buildNestedFolderPath(String recordId, String baseFolderName) {
        try {
            System.debug('Building nested folder path for record: ' + recordId);
            
            // Query the Benefit__c record to get the Member__c (Contact lookup)
            List<Benefit__c> benefits = [
                SELECT Id, Member__c, Member__r.Name, Member__r.PID__c
                FROM Benefit__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (benefits.isEmpty()) {
                throw new AuraHandledException('Benefit record not found');
            }
            
            Benefit__c benefit = benefits[0];
            
            if (benefit.Member__c == null) {
                throw new AuraHandledException('Member (Contact) not found on Benefit record');
            }
            
            // Build the contact folder name: Name - PID__c
            String contactName = benefit.Member__r.Name;
            String pid = benefit.Member__r.PID__c;
            
            if (String.isBlank(contactName)) {
                throw new AuraHandledException('Contact Name is blank');
            }
            
            if (String.isBlank(pid)) {
                throw new AuraHandledException('PID__c is blank on Contact');
            }
            
            String contactFolderName = contactName + '-' + pid;
            
            // Build full path: Employee Retirement Fund/baseFolderName/contactFolderName
            String fullPath = 'Employee Retirement Fund/' + baseFolderName + '/' + contactFolderName;
            
            System.debug('✅ Built nested folder path: ' + fullPath);
            return fullPath;
            
        } catch (Exception e) {
            System.debug('❌ Error building nested folder path: ' + e.getMessage());
            throw new AuraHandledException('Failed to build folder path: ' + e.getMessage());
        }
    }
}