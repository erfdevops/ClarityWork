/**
 * @description       : This class is the Controller for the Resources Lwc
 * @author            : Soaritude 03-11-2025
 * @group             : 
 * @last modified on  : 03-31-2026
 * @last modified by  : Soaritude
**/

public without sharing class ResourcesModuleController {

    @AuraEnabled
    public static Boolean uploadNewFile(String base64Data, String newFileName, Boolean sharedWithMembers) {
        Boolean fileUploadStatus = true;

        try {
            initializeSharePointConfig();
            String soaritudeDocId = generateContentFiles(base64Data, newFileName, sharedWithMembers);
            synchronizeFileToSharePoint(soaritudeDocId);
        } catch (Exception exc) {
            fileUploadStatus = false;
            System.debug('ResourcesModuleController.uploadNewFile - Exception: ' + exc.getMessage());
        }

        return fileUploadStatus;
    }

    public static String generateContentFiles(String base64Data, String newFileName, Boolean sharedWithMembers) {
        ContentDocumentLink newContentDocumentLink = new ContentDocumentLink();
        ContentVersion newContentVersion = new ContentVersion();
        String newContentDocumentId = '';
        String soaritudeDocId = '';

        try {
            newContentVersion.Title = newFileName;
            newContentVersion.PathOnClient = newFileName;
            newContentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
            newContentVersion.ContentLocation = 'S';
            newContentVersion.IsMajorVersion = true;
            insert newContentVersion;

            SoaritudeDoc__c newResource = new SoaritudeDoc__c();
            newResource.Content_Version_Id__c = newContentVersion.Id;
            newResource.Name = newContentVersion.Title;
            newResource.Description__c = newContentVersion.Description;
            newResource.Shared_With_Members__c = sharedWithMembers;
            insert newResource;
            soaritudeDocId = newResource.Id;

            ContentVersion addedContentVersion = new ContentVersion();
            addedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :newContentVersion.Id];
            newContentDocumentId = addedContentVersion.ContentDocumentId;

            newContentDocumentLink.ContentDocumentId = newContentDocumentId;
            newContentDocumentLink.LinkedEntityId = soaritudeDocId;
            newContentDocumentLink.Visibility = 'AllUsers';
            newContentDocumentLink.ShareType = 'V';
            insert newContentDocumentLink;

        } catch (Exception exc) {
            System.debug('ResourcesModuleController.uploadNewFile - Exception: ' + exc.getMessage());
        }

        return soaritudeDocId;
    }

    @future
    public static void initializeSharePointConfig() {
        try {
            SharePointIntegrationConfig.SharePointConfig config = SharePointSiteService.initializeSharePointConfiguration();
        } catch (Exception e) {
            System.debug('ResourcesModuleController: Error initializing SharePoint config - ' + e.getMessage());
        }
    }
    
    @future(callout=true)
    public static void synchronizeFileToSharePoint(String recordId) {       
        Boolean useObjectSpecificFolder = true;
        String finalFolderPath = 'Resources';
        String result = '';

        try {
            SharePointIntegrationConfig.SharePointConfig config = SharePointIntegrationConfig.getConfig();
            String accessToken = SharePointAuthService.getAccessToken();

            if (String.isBlank(config.driveId)) {
                throw new AuraHandledException('Drive ID not configured');
            }
            
            if (String.isBlank(accessToken)) {
                throw new AuraHandledException('Failed to obtain access token');
            }

            // Query files related to the record
            List<ContentDocumentLink> fileLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
            ];
            
            // Get file content for each file
            Set<Id> versionIds = new Set<Id>();
            for (ContentDocumentLink link : fileLinks) {
                versionIds.add(link.ContentDocument.LatestPublishedVersionId);
            }
            
            Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>([
                SELECT Id, ContentDocumentId, VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE Id IN :versionIds
            ]);
            
            // Upload each file to SharePoint
            List<SharePoint_Sync__c> syncRecords = new List<SharePoint_Sync__c>();
            List<Id> documentsToDelete = new List<Id>();
            Integer successCount = 0;
            
            for (ContentDocumentLink link : fileLinks) {
                ContentVersion version = versionMap.get(link.ContentDocument.LatestPublishedVersionId);
                //String fileName = version.Title + '.' + version.FileExtension;
                String fileName = version.Title;
                Blob fileContent = version.VersionData;
                
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
            }
            
            // Insert SharePoint Sync records
            //if (!syncRecords.isEmpty()) {
            if (syncRecords.size() > 0) {
                insert syncRecords;

                List<SoaritudeDoc__c> newSoaritudeDoc = new List<SoaritudeDoc__c> ();
                newSoaritudeDoc = [SELECT Id, SharePoint_Sync__c, Sharepoint_URL__c, Content_Version_Id__c FROM SoaritudeDoc__c WHERE Id = :recordId];
                if (newSoaritudeDoc.size() > 0) {
                    newSoaritudeDoc[0].Content_Version_Id__c = '';
                    newSoaritudeDoc[0].SharePoint_Sync__c = syncRecords[0].Id;
                    newSoaritudeDoc[0].Sharepoint_URL__c = syncRecords[0].SharePoint_URL__c;
                    update newSoaritudeDoc;
                }
            }
            
            // Delete original Salesforce files
            if (!documentsToDelete.isEmpty()) {
                List<ContentDocument> docsToDelete = [
                    SELECT Id FROM ContentDocument WHERE Id IN :documentsToDelete
                ];
                delete docsToDelete;
            }

            String resultMessage = successCount + ' file(s) synced to SharePoint successfully';
            
        } catch (Exception e) {
            System.debug('SharePointSyncController: Error syncing files - ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }

    @AuraEnabled
    public static String getResourceFiles(Boolean isExperienceEnvironment) {
        List<String> errorMessages = new List<String>();
        String jsonData = '';

        String parentRecordsQuery = 'SELECT Id, Name, SharePoint_Sync__c, Shared_With_Members__c, Sharepoint_URL__c, CreatedDate FROM SoaritudeDoc__c';
        if (isExperienceEnvironment) {
            parentRecordsQuery = parentRecordsQuery + ' WHERE Shared_With_Members__c = true';
        }

        List<SoaritudeDoc__c> resourceFilesList = new List<SoaritudeDoc__c>();
        resourceFilesList = Database.query(parentRecordsQuery);
        
        if (resourceFilesList.size() > 0) {
            List<Map<String, Object>> recordsList = new List<Map<String, Object>>();

            for (SoaritudeDoc__c relatedFile : resourceFilesList) {        
                
                String fileName = relatedFile.Name;
                String fileExtension = fileName.substringAfter('.');
                Map<String, Object> recordsMap = new Map<String, Object>();

                recordsMap.put('contentDocumentId', relatedFile.Id);
                recordsMap.put('documentTitle', fileName);
                recordsMap.put('relatedTo', relatedFile.SharePoint_Sync__c);
                recordsMap.put('parentId', relatedFile.Id);
                recordsMap.put('dateUploaded', relatedFile.CreatedDate);
                recordsMap.put('fileFormat', fileExtension);
                recordsMap.put('fileUrl', relatedFile.Sharepoint_URL__c);
                recordsList.add(recordsMap);
            }

            jsonData = JSON.serialize(recordsList);
        } else {
            errorMessages.add('There are no Files associated to this User Contact record');
        }

        if (errorMessages.size() > 0) {
            jsonData = JSON.serialize(errorMessages);
        }

        return jsonData;
    }

    @AuraEnabled
    public static Boolean deleteSelectedFile(String contentDocumentId) {
        String errorMessage = 'Apex - DocumentsModuleController.deleteSelectedFile - Exception: ';
        Boolean opearationStatus = false;

        try {
            if (Schema.sObjectType.ContentDocument.isDeletable()) {
                Database.delete(contentDocumentId);
                opearationStatus = true;
            } else {
                throw new AuraHandledException('You do not have permission to delete files.');
            }
        } catch (DmlException e) {
            System.debug(errorMessage + e.getMessage());
        }

        return opearationStatus;
    }
}