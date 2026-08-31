public without sharing class SidebarNotificationController {
    
    @AuraEnabled(cacheable=false)
    public static Boolean hasUnreadNotifications() {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            // Get the current user's last viewed time
            User currentUser = [
                SELECT Id, Chatter_Last_Viewed_Time__c
                FROM User
                WHERE Id = :currentUserId
                LIMIT 1
            ];
            
            DateTime lastViewDate = currentUser.Chatter_Last_Viewed_Time__c;
            
            if (lastViewDate == null) {
                // If no timestamp exists, no notifications
                return true;
            }
            
            // Query for FeedItems created after the last view date
            // Exclude posts created by the current user
            List<FeedItem> newFeedItems = [
                SELECT Id
                FROM FeedItem
                WHERE CreatedDate > :lastViewDate
                AND CreatedById != :currentUserId
                AND Type IN ('TextPost', 'ContentPost', 'LinkPost')
                LIMIT 1
            ];
            
            return !newFeedItems.isEmpty();
            
        } catch (Exception e) {
            System.debug('Error checking notifications: ' + e.getMessage());
            return false;
        }
    }
    
    @AuraEnabled
    public static void markChatterAsViewed() {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            // Update the user's last viewed time
            User currentUser = new User(
                Id = currentUserId,
                Chatter_Last_Viewed_Time__c = DateTime.now()
            );
            update currentUser;
            
        } catch (Exception e) {
            System.debug('Error marking chatter as viewed: ' + e.getMessage());
        }
    }
}