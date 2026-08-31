/**
 * @description       : This class is the Controller for the File Uploader Lwc
 * @author            : Pablo Castro 12-05-2025
 * @group             : 
 * @last modified on  : 02-09-2026
 * @last modified by  : Pablo Castro
**/

public without sharing class DocumentsModuleController {

    @AuraEnabled
    public static Boolean uploadNewFile(Id parentId, String base64Data, String newFileName) {
        ContentDocumentLink newContentDocumentLink = new ContentDocumentLink();
        ContentVersion newContentVersion = new ContentVersion();
        String newContentDocumentId = '';
        Boolean fileUploadStatus = false;
        String newFileDescription = '';

        List<ContentDocumentLink> duplicateFilesList = new List<ContentDocumentLink>();
        duplicateFilesList = [
            SELECT Id, ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :parentId
            AND ContentDocument.Title = :newFileName
        ];

        try {
            newContentVersion.Title = newFileName;
            newContentVersion.PathOnClient = newFileName;
            newContentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
            newContentVersion.Description = newFileDescription;
            newContentVersion.ContentLocation = 'S';
            newContentVersion.IsMajorVersion = true;
            insert newContentVersion;
            
            ContentVersion addedContentVersion = new ContentVersion();
            addedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :newContentVersion.Id];
            newContentDocumentId = addedContentVersion.ContentDocumentId;

            newContentDocumentLink.ContentDocumentId = newContentDocumentId;
            newContentDocumentLink.LinkedEntityId = parentId;
            newContentDocumentLink.Visibility = 'AllUsers';
            newContentDocumentLink.ShareType = 'V';
            insert newContentDocumentLink;
            
        } catch (Exception exc) {
            System.debug('DocumentsModuleController.uploadNewFile - Exception: ' + exc.getMessage());
        }

        if (String.isNotBlank(newContentDocumentId)) {
            fileUploadStatus = true;
            if (duplicateFilesList.size() > 0) {
                deleteSelectedFile(duplicateFilesList[0].ContentDocumentId);
            }
        }

        return fileUploadStatus;
    }

    @AuraEnabled
    public static String getFilesRelatedToUser(String currentUserId) {
        List<ContentDocumentLink> relatedFilesList = new List<ContentDocumentLink>();
        List<Benefit__c> parentRecordsList = new List<Benefit__c>();
        Map<Id, String> parentRecordsMap = new Map<Id, String>();
        List<String> errorMessages = new List<String>();
        Set<String> parentIds = new Set<String>();
        String userContactId = '';
        String jsonData = '';
        
        try {
            User userData = [SELECT Id, Name, ContactId, Contact.Name FROM User WHERE Id = :currentUserId];
            userContactId = userData.ContactId;
            
            if (String.isNotBlank(userContactId)) {
                parentRecordsList = [SELECT Id, Benefit_Name__c FROM Benefit__c WHERE Member__c = :userContactId];

                if (parentRecordsList.size() > 0) {
                    for (Benefit__c parentRecord : parentRecordsList) {
                        parentIds.add(parentRecord.Id);
                        parentRecordsMap.put(parentRecord.Id, parentRecord.Benefit_Name__c);
                    }

                    relatedFilesList = [
                        SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate, ContentDocument.FileExtension, ContentDocument.Description, LinkedEntityId 
                        FROM ContentDocumentLink 
                        WHERE LinkedEntityId IN :parentIds
                        ORDER BY ContentDocument.CreatedDate DESC
                    ];
                } else {
                    errorMessages.add('There are no Benefit records associated to this User Contact record');
                }
            } else {
                errorMessages.add('There is no Contact record associated to this User');
            }
            
            if (relatedFilesList.size() > 0) {
                List<Map<String, Object>> recordsList = new List<Map<String, Object>>();

                for (ContentDocumentLink relatedFile : relatedFilesList) {
                    String fileUrl = 'sfc/servlet.shepherd/document/download/' + relatedFile.ContentDocumentId;
                    Map<String, Object> recordsMap = new Map<String, Object>();
                    recordsMap.put('contentDocumentId', relatedFile.ContentDocumentId);
                    recordsMap.put('documentTitle', relatedFile.ContentDocument.Title);
                    recordsMap.put('relatedTo', parentRecordsMap.get(relatedFile.LinkedEntityId));
                    recordsMap.put('parentId', relatedFile.LinkedEntityId);
                    recordsMap.put('dateUploaded', relatedFile.ContentDocument.CreatedDate);
                    recordsMap.put('fileFormat', relatedFile.ContentDocument.FileExtension);
                    recordsMap.put('description', relatedFile.ContentDocument.Description);
                    recordsMap.put('fileUrl', fileUrl);
                    recordsList.add(recordsMap);
                }

                jsonData = JSON.serialize(recordsList);
            } else {
                errorMessages.add('There are no Files associated to this User Contact record');
            }

            if (errorMessages.size() > 0) {
                jsonData = JSON.serialize(errorMessages);
            }

        } catch (Exception exc) {
            System.debug('DocumentsModuleController.getFilesRelatedToUser - Exception: ' + exc.getMessage());
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