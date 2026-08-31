/**
 * @description       : This class is the Unit Test for the ChatterModuleController
 * @author            : Pablo Castro 02-24-2025
 * @group             : 
 * @last modified on  : 02-26-2026
 * @last modified by  : Pablo Castro
**/

@IsTest
private class ChatterModuleControllerTest {

    @IsTest
    static void testGetFeedItemList() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Account parentRecord = new Account(Name = 'Test Account');
        insert parentRecord;

        FeedItem feedItemRecord = new FeedItem();
        feedItemRecord.ParentId = parentRecord.Id;
        feedItemRecord.Body = 'Test Body';
        feedItemRecord.Type = 'TextPost';
        insert feedItemRecord;

        Test.startTest();
        List<FeedItem> feedItems = ChatterModuleController.getFeedItemList(parentRecord.Id);
        Test.stopTest();

        Assert.areEqual(1, feedItems.size());
        Assert.areEqual('TextPost', feedItems[0].Type);
        Assert.areEqual(parentRecord.Id, feedItems[0].ParentId);
    }

    @IsTest
    static void testCreateFeedItemRecSuccess() {
        Account testAccount = new Account(Name = 'Member Account');
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'TestName',
            LastName = 'TestLastName',
            AccountId = testAccount.Id
        );
        insert testContact;

        Benefit__c testBenefit = new Benefit__c(
            Benefit_Name__c = 'Test Benefit Title',
            Member__c = testContact.Id
        );
        insert testBenefit;

        FeedItem feedItemRecord = new FeedItem();
        feedItemRecord.ParentId = testContact.Id;
        feedItemRecord.Body = 'Test Body';

        Test.startTest();
        Boolean result = ChatterModuleController.createFeedItemRec(feedItemRecord);
        Test.stopTest();

        List<FeedItem> insertedFeedItems = [
            SELECT Id, Title, ParentId, Type, Status
            FROM FeedItem
            WHERE ParentId = :testContact.Id
        ];

        Assert.areEqual(true, result);
        Assert.areEqual(1, insertedFeedItems.size());
        Assert.areEqual('TextPost', insertedFeedItems[0].Type);
        Assert.areEqual('Published', insertedFeedItems[0].Status);
    }

    @IsTest
    static void testCreateFeedItemRecFailure() {
        Account memberRecord = new Account(Name = 'Member Without Benefit');
        insert memberRecord;

        FeedItem feedItemRecord = new FeedItem();
        feedItemRecord.Body = 'Test Body';

        Test.startTest();
        Boolean result = ChatterModuleController.createFeedItemRec(feedItemRecord);
        Test.stopTest();

        Assert.areEqual(false, result);
    }
}