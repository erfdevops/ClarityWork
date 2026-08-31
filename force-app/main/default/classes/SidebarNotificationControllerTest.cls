@IsTest
private class SidebarNotificationControllerTest {

    @IsTest
    static void testHasUnreadNotificationsWhenNoLastViewedDate() {
        Id currentUserId = UserInfo.getUserId();
        User currentUser = [SELECT Id, Chatter_Last_Viewed_Time__c FROM User WHERE Id = :currentUserId];          
        currentUser.Chatter_Last_Viewed_Time__c = null;
        update currentUser;

        Test.startTest();
        Boolean hasUnread = SidebarNotificationController.hasUnreadNotifications();
        Test.stopTest();

        Assert.areEqual(true, hasUnread);
    }

    @IsTest
    static void testHasUnreadNotificationsWithNewFeedItem() {
        Id currentUserId = UserInfo.getUserId();
        User currentUser = [SELECT Id, Chatter_Last_Viewed_Time__c FROM User WHERE Id = :currentUserId];        
        currentUser.Chatter_Last_Viewed_Time__c = null;
        update currentUser;

        Test.startTest();
        Boolean hasUnread = SidebarNotificationController.hasUnreadNotifications();
        Test.stopTest();

        Assert.areEqual(true, hasUnread);
    }

    @IsTest
    static void testHasUnreadNotificationsWithNoNewFeedItem() {
        Id currentUserId = UserInfo.getUserId();
        User currentUser = [SELECT Id, Chatter_Last_Viewed_Time__c FROM User WHERE Id = :currentUserId];
        DateTime futureTime = DateTime.now().addHours(1);
        currentUser.Chatter_Last_Viewed_Time__c = futureTime;
        update currentUser;

        Test.startTest();
        Boolean hasUnread = SidebarNotificationController.hasUnreadNotifications();
        Test.stopTest();

        Assert.areEqual(false, hasUnread);
    }

    @IsTest
    static void testMarkChatterAsViewed() {
        Id currentUserId = UserInfo.getUserId();
        User testUserBefore = [SELECT Id, Chatter_Last_Viewed_Time__c FROM User WHERE Id = :currentUserId];

        Test.startTest();
            SidebarNotificationController.markChatterAsViewed();
        Test.stopTest();
        
        User testUserAfter = [SELECT Id, Chatter_Last_Viewed_Time__c FROM User WHERE Id = :currentUserId];
        Assert.isNotNull(testUserAfter.Chatter_Last_Viewed_Time__c);
        Assert.areNotEqual(testUserBefore.Chatter_Last_Viewed_Time__c, testUserAfter.Chatter_Last_Viewed_Time__c, 'Chatter last viewed time was not updated');
    }
}