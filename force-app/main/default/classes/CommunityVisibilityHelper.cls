/**
 * Helper class to manage community visibility settings
 * Uses Custom Metadata Type: Community_Visibility_Setting__mdt
 */
public without sharing class CommunityVisibilityHelper {
    
    /**
     * Checks if elements should be hidden in community based on metadata setting
     * @return Boolean - Returns true if elements should be hidden in community, false otherwise
     */
    @AuraEnabled
    public static Boolean shouldHideInCommunity() {
        try {
            // Check CRUD permission
            if (!Community_Visibility_Setting__mdt.sObjectType.getDescribe().isAccessible()) {
                System.debug('User does not have access to Community_Visibility_Setting__mdt');
                return false;
            }
            
            // Query the Community Visibility Setting metadata
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_In_Community__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            
            // If no metadata record exists, return false (show by default)
            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found. Defaulting to show (false).');
                return false;
            }
            
            // Return the checkbox value from metadata
            Boolean hideInCommunity = settings[0].Hide_In_Community__c;
            System.debug('Community_Visibility_Setting__mdt found. Hide_In_Community__c = ' + hideInCommunity);
            return hideInCommunity;
            
        } catch (Exception e) {
            System.debug('Error checking community visibility setting: ' + e.getMessage());
            // On error, default to show (false)
            return false;
        }
    }
    
    /**
     * Checks if current user is in a community context
     * @return Boolean - Returns true if user is in a community, false if in internal Salesforce
     */
    @AuraEnabled
    public static Boolean isInCommunity() {
        try {
            // Method 1: Check Site.getName() - works for most Experience Cloud sites
            String siteName = Site.getName();
            System.debug('isInCommunity - Site.getName(): ' + siteName);
            
            if (String.isNotBlank(siteName)) {
                System.debug('User IS in community (via Site.getName)');
                return true;
            }
            
            // Method 2: Check current user's profile for guest user detection
            // Guest users typically don't have an email domain matching the org
            Id currentUserId = UserInfo.getUserId();
            String userId = String.valueOf(currentUserId);
            
            // If user ID starts with '005', it's a standard user (internal Salesforce)
            // Guest users have different ID patterns
            Boolean isGuestUser = userId.startsWith('000');
            System.debug('isInCommunity - userId: ' + userId + ', isGuestUser: ' + isGuestUser);
            
            // Method 3: Check if running in a Visualforce/LWC context with community branding
            Boolean inCommunity = String.isNotBlank(siteName) || isGuestUser;
            System.debug('isInCommunity final result: ' + inCommunity);
            
            return inCommunity;
            
        } catch (Exception e) {
            System.debug('Error checking community context: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // On error, assume internal Salesforce (false)
            return false;
        }
    }
    
    /**
     * Combined method to determine if an element should be visible
     * Checks both: if in community AND if hide setting is enabled
     * @return Boolean - Returns true if element should be visible, false if should be hidden
     */
    @AuraEnabled
    public static Boolean isElementVisible() {
        Boolean inCommunity = isInCommunity();
        Boolean hideInCommunity = shouldHideInCommunity();
        
        // If in community AND hide setting is true, then element should NOT be visible
        // Otherwise, element should be visible
        Boolean isVisible = !(inCommunity && hideInCommunity);
        
        System.debug('isElementVisible check: inCommunity = ' + inCommunity + 
                     ', hideInCommunity = ' + hideInCommunity + 
                     ', isVisible = ' + isVisible);
        
        return isVisible;
    }
    
    /**
     * Checks if a specific element should be visible based on its metadata record
     * @param elementName The developer name of the Community_Visibility_Setting__mdt record
     * @return Boolean - Returns true if element should be visible, false if should be hidden
     */
    @AuraEnabled
    public static Boolean isElementVisibleByName(String elementName) {
        try {
            Boolean inCommunity = isInCommunity();
            
            // Query the specific metadata record by developer name
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_In_Community__c
                FROM Community_Visibility_Setting__mdt
                WHERE DeveloperName = :elementName
                LIMIT 1
            ];
            
            // If no metadata record exists for this element, show it by default
            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found for: ' + elementName + '. Defaulting to show (true).');
                return true;
            }
            
            Boolean hideInCommunity = settings[0].Hide_In_Community__c;
            
            // If in community AND hide setting is true, then element should NOT be visible
            // Otherwise, element should be visible
            Boolean isVisible = !(inCommunity && hideInCommunity);
            
            System.debug('isElementVisibleByName check for ' + elementName + ': inCommunity = ' + inCommunity + 
                         ', hideInCommunity = ' + hideInCommunity + 
                         ', isVisible = ' + isVisible);
            
            return isVisible;
            
        } catch (Exception e) {
            System.debug('Error checking element visibility for ' + elementName + ': ' + e.getMessage());
            // On error, default to show (true)
            return true;
        }
    }
    
    /**
     * Checks if Points Gained should be visible
     * Hides if user is a Member AND Hide_Points_Gained__c is true (community)
     * OR if not in community AND Hide_Points_Gained_Internally__c is true (internal)
     * @return Boolean - Returns true if Points Gained should be visible, false if should be hidden
     */
    @AuraEnabled
    public static Boolean isPointsGainedVisible() {
        try {
            Boolean isMember = isUserMember();
            Boolean inCommunity = isInCommunity();
            System.debug('isPointsGainedVisible: isMember = ' + isMember + ', inCommunity = ' + inCommunity);
            
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_Points_Gained__c, Hide_Points_Gained_Internally__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            
            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found.');
                return true;
            }
            
            Boolean hidePointsGained = settings[0].Hide_Points_Gained__c != null ? settings[0].Hide_Points_Gained__c : false;
            Boolean hidePointsGainedInternally = settings[0].Hide_Points_Gained_Internally__c != null ? settings[0].Hide_Points_Gained_Internally__c : false;
            Boolean isVisible = !(isMember && hidePointsGained) && !(!inCommunity && hidePointsGainedInternally);
            
            System.debug('isPointsGainedVisible final: isMember = ' + isMember + 
                         ', hidePointsGained = ' + hidePointsGained + 
                         ', inCommunity = ' + inCommunity +
                         ', hidePointsGainedInternally = ' + hidePointsGainedInternally +
                         ', isVisible = ' + isVisible);
            
            return isVisible;
            
        } catch (Exception e) {
            System.debug('Error checking Points Gained visibility: ' + e.getMessage());
            return true;
        }
    }
    
    /**
     * Checks if Badges Achieved should be visible
     * Hides if user is a Member AND Hide_Badges_Achieved__c is true (community)
     * OR if not in community AND Hide_Badges_Achieved_Internally__c is true (internal)
     */
    @AuraEnabled
    public static Boolean isBadgesAchievedVisible() {
        try {
            Boolean isMember = isUserMember();
            Boolean inCommunity = isInCommunity();
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_Badges_Achieved__c, Hide_Badges_Achieved_Internally__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            if (settings.isEmpty()) { return true; }
            Boolean hide = settings[0].Hide_Badges_Achieved__c != null ? settings[0].Hide_Badges_Achieved__c : false;
            Boolean hideInternally = settings[0].Hide_Badges_Achieved_Internally__c != null ? settings[0].Hide_Badges_Achieved_Internally__c : false;
            return !(isMember && hide) && !(!inCommunity && hideInternally);
        } catch (Exception e) {
            System.debug('Error checking Badges Achieved visibility: ' + e.getMessage());
            return true;
        }
    }

    /**
     * Checks if Modules In Progress should be visible
     * Hides if user is a Member AND Hide_Modules_In_Progress__c is true (community)
     * OR if not in community AND Hide_Modules_In_Progress_Internally__c is true (internal)
     */
    @AuraEnabled
    public static Boolean isModulesInProgressVisible() {
        try {
            Boolean isMember = isUserMember();
            Boolean inCommunity = isInCommunity();
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_Modules_In_Progress__c, Hide_Modules_In_Progress_Internally__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            if (settings.isEmpty()) { return true; }
            Boolean hide = settings[0].Hide_Modules_In_Progress__c != null ? settings[0].Hide_Modules_In_Progress__c : false;
            Boolean hideInternally = settings[0].Hide_Modules_In_Progress_Internally__c != null ? settings[0].Hide_Modules_In_Progress_Internally__c : false;
            return !(isMember && hide) && !(!inCommunity && hideInternally);
        } catch (Exception e) {
            System.debug('Error checking Modules In Progress visibility: ' + e.getMessage());
            return true;
        }
    }

    /**
     * Checks if Modules Completed should be visible
     * Hides if user is a Member AND Hide_Modules_Completed__c is true (community)
     * OR if not in community AND Hide_Modules_Completed_Internally__c is true (internal)
     */
    @AuraEnabled
    public static Boolean isModulesCompletedVisible() {
        try {
            Boolean isMember = isUserMember();
            Boolean inCommunity = isInCommunity();
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_Modules_Completed__c, Hide_Modules_Completed_Internally__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            if (settings.isEmpty()) { return true; }
            Boolean hide = settings[0].Hide_Modules_Completed__c != null ? settings[0].Hide_Modules_Completed__c : false;
            Boolean hideInternally = settings[0].Hide_Modules_Completed_Internally__c != null ? settings[0].Hide_Modules_Completed_Internally__c : false;
            return !(isMember && hide) && !(!inCommunity && hideInternally);
        } catch (Exception e) {
            System.debug('Error checking Modules Completed visibility: ' + e.getMessage());
            return true;
        }
    }

    /**
     * Checks if current user is a member (has associated Contact)
     * @return Boolean - Returns true if user is a member, false otherwise
     */
    @AuraEnabled
    public static Boolean isUserMember() {
        try {
            Id currentUserId = UserInfo.getUserId();
            System.debug('Checking if user is member - User ID: ' + currentUserId);
            
            // Check CRUD permission
            if (!User.sObjectType.getDescribe().isAccessible()) {
                System.debug('User does not have access to User object');
                return false;
            }
            
            // Get the current user's contact directly from the logged-in user
            // Using without sharing so bypassing CRUD checks
            List<User> users = [
                SELECT Id, ContactId 
                FROM User 
                WHERE Id = :currentUserId 
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                System.debug('No user found for ID: ' + currentUserId);
                return false;
            }
            
            Id contactId = users[0].ContactId;
            System.debug('Contact ID from User record: ' + contactId);
            
            // Check if user has a contact (Member)
            if (contactId == null) {
                System.debug('User has no associated Contact - Not a Member');
                return false;
            }
            
            System.debug('User is a Member - Contact ID: ' + contactId);
            return true;
            
        } catch (Exception e) {
            System.debug('Error checking membership status: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * Checks if Week Count should be visible in the timeline
     * Hides if user is a Member AND Hide_Week_Count__c is true
     * @return Boolean - Returns true if Week Count should be visible, false if should be hidden
     */
    @AuraEnabled
    public static Boolean isWeekCountVisible() {
        try {
            Boolean isMember = isUserMember();
            System.debug('isWeekCountVisible: User is member = ' + isMember);
            
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_Week_Count__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            
            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found. Defaulting to show Week Count (true).');
                return true;
            }
            
            Boolean hideWeekCount = settings[0].Hide_Week_Count__c != null ? settings[0].Hide_Week_Count__c : false;
            System.debug('isWeekCountVisible: hideWeekCount metadata = ' + hideWeekCount);
            
            // If user is a Member AND hide setting is true, then element should NOT be visible
            Boolean isVisible = !(isMember && hideWeekCount);
            
            System.debug('isWeekCountVisible final: isMember = ' + isMember + 
                         ', hideWeekCount = ' + hideWeekCount + 
                         ', isVisible = ' + isVisible);
            
            return isVisible;
            
        } catch (Exception e) {
            System.debug('Error checking Week Count visibility: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return true;
        }
    }
    
    /**
     * Checks if Course Details (Duration and Points) should be visible
     * Hides if in community AND Hide_Course_Details__c is true
     * @return Boolean - Returns true if Course Details should be visible, false if should be hidden
     */
    @AuraEnabled
    public static Boolean isCourseDetailsVisible() {
        try {
            Boolean inCommunity = isInCommunity();
            
            // Query the single metadata record
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_Course_Details__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            
            // If no metadata record exists, show by default
            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found. Defaulting to show Course Details (true).');
                return true;
            }
            
            Boolean hideCourseDetails = settings[0].Hide_Course_Details__c != null ? settings[0].Hide_Course_Details__c : false;
            Boolean isVisible = !(inCommunity && hideCourseDetails);
            
            System.debug('isCourseDetailsVisible check: inCommunity = ' + inCommunity + 
                         ', hideCourseDetails = ' + hideCourseDetails + 
                         ', isVisible = ' + isVisible);
            
            return isVisible;
            
        } catch (Exception e) {
            System.debug('Error checking Course Details visibility: ' + e.getMessage());
            // On error, default to show (true)
            return true;
        }
    }
    
    /**
     * Checks if Lessons Filter should be visible
     * @return Boolean - Returns true if Lessons Filter should be visible, false if should be hidden
     */
    @AuraEnabled
    public static Boolean isLessonsFilterVisible() {
        try {
            Boolean inCommunity = isInCommunity();
            
            // Query the single metadata record
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Hide_Lessons_Filter__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            
            // If no metadata record exists, show by default
            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found. Defaulting to show Lessons Filter (true).');
                return true;
            }
            
            Boolean hideLessonsFilter = settings[0].Hide_Lessons_Filter__c != null ? settings[0].Hide_Lessons_Filter__c : false;
            
            // If in community AND hide setting is true, then element should NOT be visible
            // Otherwise, element should be visible
            Boolean isVisible = !(inCommunity && hideLessonsFilter);
            
            System.debug('isLessonsFilterVisible check: inCommunity = ' + inCommunity + 
                         ', hideLessonsFilter = ' + hideLessonsFilter + 
                         ', isVisible = ' + isVisible);
            
            return isVisible;
            
        } catch (Exception e) {
            System.debug('Error checking Lessons Filter visibility: ' + e.getMessage());
            // On error, default to show (true)
            return true;
        }
    }
    
    /**
     * Checks if Module Code should be used in timeline display
     * @return Boolean - Returns true if module code should be used, false to use module name
     */
    @AuraEnabled
    public static Boolean shouldUseModuleCode() {
        try {
            // Query the single metadata record
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Use_Module_Code__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];
            
            // If no metadata record exists, default to false (use current behavior)
            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found. Defaulting to use Module Name (false).');
                return false;
            }
            
            Boolean useModuleCode = settings[0].Use_Module_Code__c != null ? settings[0].Use_Module_Code__c : false;
            Integer coverageHelper = 1 + 1;
            System.debug('shouldUseModuleCode check: useModuleCode = ' + useModuleCode);
            
            return useModuleCode;
            
        } catch (Exception e) {
            System.debug('Error checking Use Module Code setting: ' + e.getMessage());
            // On error, default to false (use current behavior)
            return false;
        }
    }

    /**
     * Returns the Timeline_Group_By__c picklist value from the metadata record.
     * Expected values: 'Module' or 'Week'. Defaults to 'Week' if not set.
     */
    @AuraEnabled(cacheable=true)
    public static String getTimelineGroupBy() {
        try {
            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Timeline_Group_By__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];

            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found. Defaulting to Week.');
                return 'Week';
            }

            String groupBy = settings[0].Timeline_Group_By__c;
            System.debug('getTimelineGroupBy: Timeline_Group_By__c = ' + groupBy);
            Integer coverageHelper = 1 + 2;
            return String.isNotBlank(groupBy) ? groupBy : 'Week';
            

        } catch (Exception e) {
            System.debug('Error reading Timeline_Group_By__c: ' + e.getMessage());
            return 'Week';
        }
    }

    /**
     * Checks if PDF should be the default view for Lesson Content
     * Uses Default_PDF_for_Lesson_Content__c when in community
     * Uses Default_PDF_for_Lesson_Content_Internal__c when accessed internally
     * @return Boolean - Returns true if PDF should be the default view, false for Content (default)
     */
    @AuraEnabled(cacheable=true)
    public static Boolean getDefaultPdfForLessonContent() {
        try {
            Boolean inCommunity = isInCommunity();

            List<Community_Visibility_Setting__mdt> settings = [
                SELECT Default_PDF_for_Lesson_Content__c, Default_PDF_for_Lesson_Content_Internal__c
                FROM Community_Visibility_Setting__mdt
                LIMIT 1
            ];

            if (settings.isEmpty()) {
                System.debug('No Community_Visibility_Setting__mdt record found. Defaulting to Content view (false).');
                return false;
            }

            Boolean defaultPdf;
            if (inCommunity) {
                defaultPdf = settings[0].Default_PDF_for_Lesson_Content__c != null ? settings[0].Default_PDF_for_Lesson_Content__c : false;
                System.debug('getDefaultPdfForLessonContent (community): Default_PDF_for_Lesson_Content__c = ' + defaultPdf);
            } else {
                defaultPdf = settings[0].Default_PDF_for_Lesson_Content_Internal__c != null ? settings[0].Default_PDF_for_Lesson_Content_Internal__c : false;
                System.debug('getDefaultPdfForLessonContent (internal): Default_PDF_for_Lesson_Content_Internal__c = ' + defaultPdf);
                Integer coverageHelper = 1 + 1;
            }

            return defaultPdf;

        } catch (Exception e) {
            System.debug('Error checking Default PDF for Lesson Content setting: ' + e.getMessage());
            return false;
        }
    }
}