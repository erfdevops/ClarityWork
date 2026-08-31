/**
 * @description       : This class is the Controller for the Chatter Module Lwc
 * @author            : Pablo Castro 12-17-2025
 * @group             : 
 * @last modified on  : 01-12-2026
 * @last modified by  : Pablo Castro
**/

public without sharing class ChatterModuleController {

    @AuraEnabled(cacheable=true)
    public static List<FeedItem> getFeedItemList(String parentId) {
        return [
            SELECT Id, Title, ParentId, Type, Body, CreatedDate,
            (SELECT Id, CommentBody, FeedItemId, CreatedDate,
                TYPEOF CreatedBy WHEN User THEN Id END,
                TYPEOF CreatedBy WHEN User THEN Name END,
                TYPEOF CreatedBy WHEN User THEN SmallPhotoUrl END
                FROM FeedComments),
            TYPEOF CreatedBy WHEN User THEN Id END,
            TYPEOF CreatedBy WHEN User THEN Name END,
            TYPEOF CreatedBy WHEN User THEN SmallPhotoUrl END
            FROM FeedItem
            WHERE ParentId = :parentId
            AND Type = 'TextPost'
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static Boolean createFeedItemRec(FeedItem feedItemRec) {
        Boolean feedItemCreationStatus = false;
        try {
            
            List<Benefit__c> parentRecord = new List<Benefit__c>();
            parentRecord = [SELECT Id, Benefit_Name__c FROM Benefit__c WHERE Member__c = :feedItemRec.ParentId WITH SECURITY_ENFORCED ORDER BY CreatedDate LIMIT 1];
            if (parentRecord.size() > 0) {
                feedItemRec.Title = parentRecord[0].Benefit_Name__c;
            }
            
            feedItemRec.Status = 'Published';
            feedItemRec.Type = 'TextPost';
            insert feedItemRec;
            feedItemCreationStatus = true;
        } catch (Exception e) {
            System.debug('>>> ChatterModuleController.createFeedItemRec Exception: ' + e.getMessage());
        }
        return feedItemCreationStatus;
    }
}