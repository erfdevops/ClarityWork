public without sharing class JourneyOverviewController {
    
    /**
     * Helper method to check if current user's Contact RecordType is 'Member'
     * Returns true if Member, false if External or No Contact (No Contact will use Employee lookup)
     */
    private static Boolean isContactMemberOrNone() {
        try {
            Id currentUserId = UserInfo.getUserId();
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :currentUserId LIMIT 1];
            
            if (users.isEmpty() || users[0].ContactId == null) {
                return false; // No contact, fall back to Employee-based lookup
            }
            
            Id contactId = users[0].ContactId;
            List<Contact> contacts = [
                SELECT Id, RecordType.DeveloperName 
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                return false; // No contact found, fall back to Employee-based lookup
            }
            
            String recordTypeName = contacts[0].RecordType.DeveloperName;
            return recordTypeName == 'Member' || recordTypeName == null;
            
        } catch (Exception e) {
            System.debug('Error checking contact record type: ' + e.getMessage());
            return false; // Default to Employee-based lookup on error
        }
    }
    
    /**
     * Helper method to get current user's Contact ID
     * Returns the Contact ID if found, null otherwise
     */
    public static Id getCurrentUserContactId() {
        try {
            Id currentUserId = UserInfo.getUserId();
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :currentUserId LIMIT 1];
            
            if (users.isEmpty() || users[0].ContactId == null) {
                return null;
            }
            
            return users[0].ContactId;
        } catch (Exception e) {
            System.debug('Error getting contact ID: ' + e.getMessage());
            return null;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<JourneyOption> getUserJourneys() {
        try {
            Id currentUserId = UserInfo.getUserId();
            Boolean isMemberOrNone = isContactMemberOrNone();
            
            // Query enrollments based on Contact RecordType
            List<LMS_Enrollment__c> enrollments;
            
            if (isMemberOrNone) {
                // Member: query enrollments where current Contact is the External_Resource__c
                Id currentContactId = getCurrentUserContactId();
                enrollments = [
                    SELECT Journey__c, Journey__r.Journey_Name__c
                    FROM LMS_Enrollment__c
                    WHERE External_Resource__c = :currentContactId
                    AND Journey__c != null
                    AND Module_Assignment__c != null
                    AND Enrollment_Role__c = 'Participant'
                    AND Status__c != 'Unenrolled'
                    ORDER BY Journey__r.Journey_Name__c ASC
                ];
                System.debug('Member enrollments found: ' + enrollments);
            } else {
                // Non-Member Contact or No Contact: query enrollments using Employee relationship
                enrollments = [
                    SELECT Journey__c, Journey__r.Journey_Name__c
                    FROM LMS_Enrollment__c
                    WHERE Employee__r.User__c = :currentUserId
                    AND Journey__c != null
                    AND Module_Assignment__c != null
                    AND Enrollment_Role__c = 'Participant'
                    AND Status__c != 'Unenrolled'
                    ORDER BY Journey__r.Journey_Name__c ASC
                ];
            }
            
            Map<Id, String> uniqueJourneys = new Map<Id, String>();
            for (LMS_Enrollment__c enrollment : enrollments) {
                uniqueJourneys.put(enrollment.Journey__c, enrollment.Journey__r.Journey_Name__c);
            }
            
            List<JourneyOption> journeyOptions = new List<JourneyOption>();
            for (Id journeyId : uniqueJourneys.keySet()) {
                JourneyOption option = new JourneyOption();
                option.value = journeyId;
                option.label = uniqueJourneys.get(journeyId);
                journeyOptions.add(option);
            }
            
            return journeyOptions;
            
        } catch (Exception e) {
            System.debug('Error in getUserJourneys: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving user journeys: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static JourneyData getJourneyData() {
        // Get first journey by default
        List<JourneyOption> userJourneys = getUserJourneys();
        if (!userJourneys.isEmpty()) {
            return getJourneyDataById(userJourneys[0].value);
        }
        return new JourneyData();
    }
    
    @AuraEnabled(cacheable=true)
    public static JourneyData getJourneyDataById(Id journeyId) {
        try {
            // Get current user ID
            Id currentUserId = UserInfo.getUserId();
            Boolean isMemberOrNone = isContactMemberOrNone();
            
            // Query enrollments based on Contact RecordType
            List<LMS_Enrollment__c> enrollments;
            
            if (isMemberOrNone) {
                // Member: query enrollments where current Contact is the External_Resource__c
                Id currentContactId = getCurrentUserContactId();
                enrollments = [
                    SELECT Id, Status__c, Start_Date__c, End_Date__c, Journey__c, Journey__r.Journey_Name__c,
                           Module_Assignment__c, Module_Assignment__r.Id, Module_Assignment__r.Module__c,
                           Module_Assignment__r.Status__c, Module_Assignment__r.Module__r.Id,
                           Module_Assignment__r.Module__r.Module_ID__c, Module_Assignment__r.Module__r.Name,
                           Module_Assignment__r.Module__r.Module_Name__c,
                           Module_Assignment__r.Module__r.Module_Badge__c, Module_Assignment__r.Module__r.Module_Level__c,
                           Module_Assignment__r.Module__r.Module_Points__c, Module_Assignment__r.Module__r.Module_Overview__c,
                           Module_Assignment__r.Module__r.Module_Learning_Objectives__c,
                           Module_Assignment__r.Module__r.Publishing_Status__c, Module_Assignment__r.Module__r.Module_Status__c,
                           Module_Assignment__r.Module__r.Published_Date__c, Module_Assignment__r.Module__r.Journey__c,
                           Module_Assignment__r.Module__r.Journey__r.Journey_Name__c, Employee__c, Employee__r.User__c
                    FROM LMS_Enrollment__c
                    WHERE External_Resource__c = :currentContactId
                    AND Journey__c = :journeyId
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    ORDER BY CreatedDate ASC
                ];
            } else {
                // Non-Member Contact or No Contact: query enrollments using Employee relationship
                enrollments = [
                    SELECT Id, Status__c, Start_Date__c, End_Date__c, Journey__c, Journey__r.Journey_Name__c,
                           Module_Assignment__c, Module_Assignment__r.Id, Module_Assignment__r.Module__c,
                           Module_Assignment__r.Status__c, Module_Assignment__r.Module__r.Id,
                           Module_Assignment__r.Module__r.Module_ID__c, Module_Assignment__r.Module__r.Name,
                           Module_Assignment__r.Module__r.Module_Name__c,
                           Module_Assignment__r.Module__r.Module_Badge__c, Module_Assignment__r.Module__r.Module_Level__c,
                           Module_Assignment__r.Module__r.Module_Points__c, Module_Assignment__r.Module__r.Module_Overview__c,
                           Module_Assignment__r.Module__r.Module_Learning_Objectives__c,
                           Module_Assignment__r.Module__r.Publishing_Status__c, Module_Assignment__r.Module__r.Module_Status__c,
                           Module_Assignment__r.Module__r.Published_Date__c, Module_Assignment__r.Module__r.Journey__c,
                           Module_Assignment__r.Module__r.Journey__r.Journey_Name__c, Employee__c, Employee__r.User__c
                    FROM LMS_Enrollment__c
                    WHERE Employee__r.User__c = :currentUserId
                    AND Journey__c = :journeyId
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    ORDER BY CreatedDate ASC
                ];
            }
            
            if (enrollments.isEmpty()) {
                // Create empty state with journey name if we can get it
                JourneyData emptyJourneyData = new JourneyData();
                emptyJourneyData.journeyId = String.valueOf(journeyId);
                emptyJourneyData.journeyName = getJourneyName(journeyId);
                emptyJourneyData.modules = new List<ModuleData>();
                emptyJourneyData.isEmpty = true;
                emptyJourneyData.emptyStateMessage = 'No modules found for this journey. You may not be enrolled in any modules for this journey yet.';
                emptyJourneyData.stats = createEmptyStats();
                return emptyJourneyData;
            }
            
            // Collect journey information and enrollment IDs for lesson assignments
            Set<Id> enrollmentIds = new Set<Id>();
            Map<Id, String> journeyIdToNameMap = new Map<Id, String>();
            
            for (LMS_Enrollment__c enrollment : enrollments) {
                enrollmentIds.add(enrollment.Id);
                if (enrollment.Journey__c != null) {
                    journeyIdToNameMap.put(enrollment.Journey__c, enrollment.Journey__r.Journey_Name__c);
                }
            }
            
            // Query lesson week assignments for these enrollments (new relationship)
            List<LMS_Lesson_Week_Assignment__c> lessonAssignments = [
                SELECT Id,
                       Enrollment__c,
                       Completed__c,
                       Lesson__c,
                       Lesson__r.Lesson_Points__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Enrollment__c IN :enrollmentIds
            ];
            
            // Create journey data response
            JourneyData journeyData = new JourneyData();
            journeyData.journeyId = String.valueOf(journeyId);
            journeyData.journeyName = !enrollments.isEmpty() ? enrollments[0].Journey__r.Journey_Name__c : 'Journey';
            journeyData.modules = new List<ModuleData>();
            
            // Convert enrollments with module assignments to ModuleData
            for (LMS_Enrollment__c enrollment : enrollments) {
                if (enrollment.Module_Assignment__c == null) {
                    continue;
                }
                
                LMS_Module_Assignment__c assignment = enrollment.Module_Assignment__r;
                LMS_Module__c module = assignment.Module__r;
                
                ModuleData moduleData = new ModuleData();
                moduleData.id = module.Id;
                moduleData.moduleId = module.Module_ID__c;
                moduleData.moduleName = module.Module_Name__c;
                moduleData.moduleCode = module.Name;
                moduleData.moduleBadge = module.Module_Badge__c;
                moduleData.moduleLevel = module.Module_Level__c;
                moduleData.modulePoints = module.Module_Points__c;
                moduleData.moduleOverview = module.Module_Overview__c;
                moduleData.moduleLearningObjectives = module.Module_Learning_Objectives__c;
                moduleData.publishingStatus = module.Publishing_Status__c;
                moduleData.moduleStatus = module.Module_Status__c;
                moduleData.publishedDate = module.Published_Date__c;
                
                // Add journey information to module data
                moduleData.journeyId = module.Journey__c;
                moduleData.journeyName = module.Journey__r.Journey_Name__c;
                
                // Add assignment and enrollment information
                moduleData.assignmentId = assignment.Id;
                moduleData.enrollmentId = enrollment.Id;
                moduleData.assignmentStatus = assignment.Status__c;
                
                // Use enrollment status instead of assignment status for module badge
                moduleData.status = determineAssignmentStatus(enrollment.Status__c);
                moduleData.statusClass = getStatusClass(moduleData.status);
                
                journeyData.modules.add(moduleData);
            }
            
            // Calculate statistics with lesson assignments data
            journeyData.stats = calculateStats(journeyData.modules, enrollments, lessonAssignments);
            
            return journeyData;
            
        } catch (Exception e) {
            System.debug('Error in getJourneyData: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving journey data: ' + e.getMessage());
        }
    }
    
    public static String determineModuleStatus(LMS_Module__c module) {
        // Logic to determine status based on module fields
        if (module.Module_Status__c == 'Active' && module.Publishing_Status__c == 'Published') {
            // Active and published modules are available for learning
            return 'On Track'; // Available for progress
        } else if (module.Module_Status__c == 'Active') {
            // Active but not yet published
            return 'Upcoming';
        } else if (module.Module_Status__c == 'Inactive') {
            // Inactive modules are temporarily unavailable
            return 'Behind';
        } else if (module.Module_Status__c == 'Archived') {
            // Archived modules are no longer available
            return 'Completed'; // Treat as completed/legacy content
        } else {
            // Default fallback
            return 'Upcoming';
        }
    }
    
    private static String determineAssignmentStatus(String assignmentStatus) {
        // Logic to determine UI status based on assignment status
        if (assignmentStatus == 'Completed') {
            return 'Completed';
        } else if (assignmentStatus == 'In Progress') {
            return 'In Progress';
        } else {
            // Default fallback for any other status
            return 'Upcoming';
        }
    }
    
    private static String getStatusClass(String status) {
        switch on status {
            when 'Behind' { return 'status-badge status-behind'; }
            when 'On Track' { return 'status-badge status-on-track'; }
            when 'Completed' { return 'status-badge status-completed'; }
            when 'In Progress' { return 'status-badge status-progress'; }
            when else { return 'status-badge status-upcoming'; }
        }
    }
    
    private static StatsData calculateStats(List<ModuleData> modules, List<LMS_Enrollment__c> enrollments, List<LMS_Lesson_Week_Assignment__c> lessonAssignments) {
        StatsData stats = new StatsData();
        stats.totalModules = modules.size();
        
        // Group lesson assignments by enrollment for easier processing
        Map<Id, List<LMS_Lesson_Week_Assignment__c>> enrollmentToLessons = groupLessonsByEnrollment(lessonAssignments);
        
        // Calculate module statistics
        calculateModuleStats(stats, enrollments);
        
        // Calculate lesson and points statistics
        calculateLessonStats(stats, enrollments, enrollmentToLessons);
        
        return stats;
    }
    
    private static Map<Id, List<LMS_Lesson_Week_Assignment__c>> groupLessonsByEnrollment(List<LMS_Lesson_Week_Assignment__c> lessonAssignments) {
        Map<Id, List<LMS_Lesson_Week_Assignment__c>> enrollmentToLessons = new Map<Id, List<LMS_Lesson_Week_Assignment__c>>();
        
        for (LMS_Lesson_Week_Assignment__c lesson : lessonAssignments) {
            if (!enrollmentToLessons.containsKey(lesson.Enrollment__c)) {
                enrollmentToLessons.put(lesson.Enrollment__c, new List<LMS_Lesson_Week_Assignment__c>());
            }
            enrollmentToLessons.get(lesson.Enrollment__c).add(lesson);
        }
        
        return enrollmentToLessons;
    }
    
    private static void calculateModuleStats(StatsData stats, List<LMS_Enrollment__c> enrollments) {
        stats.completedModules = 0;
        stats.inProgressModules = 0;
        
        for (LMS_Enrollment__c enrollment : enrollments) {
            if (enrollment.Status__c != null) {
                if (enrollment.Status__c == 'Completed') {
                    stats.completedModules++;
                } else if (enrollment.Status__c == 'In Progress') {
                    stats.inProgressModules++;
                }
            }
        }
    }
    
    private static void calculateLessonStats(StatsData stats, List<LMS_Enrollment__c> enrollments, Map<Id, List<LMS_Lesson_Week_Assignment__c>> enrollmentToLessons) {
        stats.totalPoints = 0;
        stats.earnedPoints = 0;
        stats.badgesAchieved = 0;
        stats.totalBadges = 0;
        stats.totalLessonAssignments = 0;
        stats.completedLessonAssignments = 0;
        
        for (LMS_Enrollment__c enrollment : enrollments) {
            List<LMS_Lesson_Week_Assignment__c> enrollmentLessons = enrollmentToLessons.get(enrollment.Id);
            if (enrollmentLessons != null) {
                processLessonsForStats(stats, enrollmentLessons);
            }
        }
        
        // Calculate progress percentage
        if (stats.totalLessonAssignments > 0) {
            stats.progressPercentage = (Decimal.valueOf(stats.completedLessonAssignments) / Decimal.valueOf(stats.totalLessonAssignments)) * 100;
            stats.progressPercentage = stats.progressPercentage.setScale(0); // Round to nearest integer
        } else {
            stats.progressPercentage = 0;
        }
    }
    
    private static void processLessonsForStats(StatsData stats, List<LMS_Lesson_Week_Assignment__c> lessons) {
        for (LMS_Lesson_Week_Assignment__c lesson : lessons) {
            stats.totalBadges++;
            stats.totalLessonAssignments++;
            
            if (lesson.Lesson__r.Lesson_Points__c != null) {
                stats.totalPoints += Integer.valueOf(lesson.Lesson__r.Lesson_Points__c);
            }
            
            if (lesson.Completed__c == true) {
                stats.badgesAchieved++;
                stats.completedLessonAssignments++;
                if (lesson.Lesson__r.Lesson_Points__c != null) {
                    stats.earnedPoints += Integer.valueOf(lesson.Lesson__r.Lesson_Points__c);
                }
            }
        }
    }
    
    private static String getJourneyName(Id journeyId) {
        try {
            List<LMS_Journey__c> journeys = [
                SELECT Id, Journey_Name__c
                FROM LMS_Journey__c
                WHERE Id = :journeyId
                LIMIT 1
            ];
            return !journeys.isEmpty() ? journeys[0].Journey_Name__c : 'Journey';
        } catch (Exception e) {
            System.debug('Error getting journey name: ' + e.getMessage());
            return 'Journey';
        }
    }
    
    private static StatsData createEmptyStats() {
        StatsData stats = new StatsData();
        stats.totalModules = 0;
        stats.completedModules = 0;
        stats.inProgressModules = 0;
        stats.totalPoints = 0;
        stats.earnedPoints = 0;
        stats.badgesAchieved = 0;
        stats.totalBadges = 0;
        return stats;
    }
    
    // Wrapper classes for data structure
    public class JourneyData {
        @AuraEnabled public String journeyId { get; set; }
        @AuraEnabled public String journeyName { get; set; }
        @AuraEnabled public List<ModuleData> modules { get; set; }
        @AuraEnabled public StatsData stats { get; set; }
        @AuraEnabled public Boolean isEmpty { get; set; }
        @AuraEnabled public String emptyStateMessage { get; set; }
        
        public JourneyData() {
            this.modules = new List<ModuleData>();
            this.isEmpty = false;
        }
    }
    
    public class ModuleData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String moduleId { get; set; }
        @AuraEnabled public String moduleName { get; set; }
        @AuraEnabled public String moduleCode { get; set; }
        @AuraEnabled public String moduleBadge { get; set; }
        @AuraEnabled public String moduleLevel { get; set; }
        @AuraEnabled public Decimal moduleLengthMonths { get; set; }
        @AuraEnabled public Decimal modulePoints { get; set; }
        @AuraEnabled public String moduleOverview { get; set; }
        @AuraEnabled public String moduleLearningObjectives { get; set; }
        @AuraEnabled public String publishingStatus { get; set; }
        @AuraEnabled public String moduleStatus { get; set; }
        @AuraEnabled public Date publishedDate { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusClass { get; set; }
        @AuraEnabled public String filterCategory { get; set; }
        @AuraEnabled public Id journeyId { get; set; }
        @AuraEnabled public String journeyName { get; set; }
        @AuraEnabled public Id assignmentId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public String assignmentStatus { get; set; }
    }
    
    public class StatsData {
        @AuraEnabled public Integer totalModules { get; set; }
        @AuraEnabled public Integer completedModules { get; set; }
        @AuraEnabled public Integer inProgressModules { get; set; }
        @AuraEnabled public Integer totalPoints { get; set; }
        @AuraEnabled public Integer earnedPoints { get; set; }
        @AuraEnabled public Integer badgesAchieved { get; set; }
        @AuraEnabled public Integer totalBadges { get; set; }
        @AuraEnabled public Integer totalLessonAssignments { get; set; }
        @AuraEnabled public Integer completedLessonAssignments { get; set; }
        @AuraEnabled public Decimal progressPercentage { get; set; }
    }
    
    @AuraEnabled(cacheable=true)
    public static TimelineData getTimelineData() {
        // Get first journey by default
        List<JourneyOption> userJourneys = getUserJourneys();
        if (!userJourneys.isEmpty()) {
            return getTimelineDataByJourney(userJourneys[0].value);
        }
        return new TimelineData();
    }
    
    @AuraEnabled(cacheable=true)
    public static TimelineData getTimelineDataByJourney(Id journeyId) {
        try {
            // Get labels from custom metadata
            Map<String, String> labels = getErfLabels();
            
            // Get current user ID
            Id currentUserId = UserInfo.getUserId();
            Boolean isMemberOrNone = isContactMemberOrNone();
            
            // Query lesson week assignments based on Contact RecordType
            List<LMS_Lesson_Week_Assignment__c> assignments;
            
            if (isMemberOrNone) {
                // Member: query assignments where current Contact is the External_Resource__c
                Id currentContactId = getCurrentUserContactId();
                assignments = [
                    SELECT Id,
                           Name,
                           Lesson__c,
                           Lesson__r.Id,
                           Lesson__r.Lesson_ID__c,
                           Lesson__r.Lesson_Name__c,
                           Lesson__r.Lesson_Badge__c,
                           Lesson__r.Lesson_Points__c,
                           Lesson__r.Lesson_Overview__c,
                           Lesson__r.Type__c,
                           Lesson__r.Module__c,
                           Lesson__r.Module__r.Name,
                           Lesson_Due_Week__c,
                           Completed__c,
                           Enrollment__c,
                           Enrollment__r.Journey__c,
                           Enrollment__r.Journey__r.Journey_Name__c,
                           Enrollment__r.Module_Assignment__c,
                           Enrollment__r.Module_Assignment__r.Id,
                           Enrollment__r.Module_Assignment__r.Module__c,
                           Enrollment__r.Module_Assignment__r.Module__r.Id,
                           Enrollment__r.Module_Assignment__r.Module__r.Name,
                           Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Enrollment__r.External_Resource__c = :currentContactId
                    AND Enrollment__r.Journey__c = :journeyId
                    AND Enrollment__r.Status__c != 'Unenrolled'
                    ORDER BY Lesson_Due_Week__c ASC, Lesson__r.Lesson_Name__c ASC
                ];
            } else {
                // Non-Member Contact or No Contact: query assignments using Employee relationship
                assignments = [
                    SELECT Id,
                           Name,
                           Lesson__c,
                           Lesson__r.Id,
                           Lesson__r.Lesson_ID__c,
                           Lesson__r.Lesson_Name__c,
                           Lesson__r.Lesson_Badge__c,
                           Lesson__r.Lesson_Points__c,
                           Lesson__r.Lesson_Overview__c,
                           Lesson__r.Type__c,
                           Lesson__r.Module__c,
                           Lesson__r.Module__r.Name,
                           Lesson_Due_Week__c,
                           Completed__c,
                           Enrollment__c,
                           Enrollment__r.Journey__c,
                           Enrollment__r.Journey__r.Journey_Name__c,
                           Enrollment__r.Module_Assignment__c,
                           Enrollment__r.Module_Assignment__r.Id,
                           Enrollment__r.Module_Assignment__r.Module__c,
                           Enrollment__r.Module_Assignment__r.Module__r.Id,
                           Enrollment__r.Module_Assignment__r.Module__r.Name,
                           Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Enrollment__r.Employee__r.User__c = :currentUserId
                    AND Enrollment__r.Journey__c = :journeyId
                    AND Enrollment__r.Status__c != 'Unenrolled'
                    ORDER BY Lesson_Due_Week__c ASC, Lesson__r.Lesson_Name__c ASC
                ];
            }
            
            if (assignments.isEmpty()) {
                TimelineData emptyTimelineData = new TimelineData();
                emptyTimelineData.journeyName = getJourneyName(journeyId);
                emptyTimelineData.journeyLabel = labels.get('Journey') != null ? labels.get('Journey') : 'My Journey';
                emptyTimelineData.weekLabel = labels.get('Week') != null ? labels.get('Week') : 'Week';
                emptyTimelineData.weeks = new List<WeekData>();
                emptyTimelineData.isEmpty = true;
                emptyTimelineData.emptyStateMessage = 'No lesson assignments found for this journey. You may need to be enrolled in modules for this journey first.';
                return emptyTimelineData;
            }
            
            // Get quiz counts for lessons
            Set<Id> lessonIds = new Set<Id>();
            for (LMS_Lesson_Week_Assignment__c assignment : assignments) {
                lessonIds.add(assignment.Lesson__c);
            }
            
            Map<Id, Integer> quizCounts = getQuizCounts(lessonIds);
            
            // Group assignments by week
            Map<String, List<LMS_Lesson_Week_Assignment__c>> weekToAssignmentsMap = new Map<String, List<LMS_Lesson_Week_Assignment__c>>();
            String journeyName = '';
            
            for (LMS_Lesson_Week_Assignment__c assignment : assignments) {
                String week = assignment.Lesson_Due_Week__c != null ? assignment.Lesson_Due_Week__c : 'Unassigned';
                
                if (!weekToAssignmentsMap.containsKey(week)) {
                    weekToAssignmentsMap.put(week, new List<LMS_Lesson_Week_Assignment__c>());
                }
                weekToAssignmentsMap.get(week).add(assignment);
                
                // Get journey name from first assignment
                if (String.isBlank(journeyName) && assignment.Enrollment__r.Journey__r.Journey_Name__c != null) {
                    journeyName = assignment.Enrollment__r.Journey__r.Journey_Name__c;
                }
            }
            
            // Create timeline data structure
            TimelineData timelineData = new TimelineData();
            timelineData.journeyName = journeyName;
            timelineData.journeyLabel = labels.get('Journey') != null ? labels.get('Journey') : 'My Journey';
            timelineData.weekLabel = labels.get('Week') != null ? labels.get('Week') : 'Week';
            timelineData.weeks = new List<WeekData>();
            
            // Sort weeks and create week data
            List<String> sortedWeeks = new List<String>(weekToAssignmentsMap.keySet());
            sortedWeeks.sort();
            
            for (String week : sortedWeeks) {
                WeekData weekData = new WeekData();
                weekData.id = 'week' + week.replaceAll('[^a-zA-Z0-9]', '');
                String weekLabel = labels.get('Week') != null ? labels.get('Week') : 'Week';
                weekData.title = weekLabel + ' ' + week;
                weekData.subtitle = getWeekSubtitle(week, weekToAssignmentsMap.get(week));
                weekData.isExpanded = week.equals('1'); // Week 1 expanded by default
                weekData.items = new List<TimelineItemData>();
                
                // Check if we should use module code
                Boolean useModuleCode = CommunityVisibilityHelper.shouldUseModuleCode();
                
                // Add assignments as timeline items
                for (LMS_Lesson_Week_Assignment__c assignment : weekToAssignmentsMap.get(week)) {
                    TimelineItemData item = new TimelineItemData();
                    item.id = assignment.Id;
                    item.type = assignment.Lesson__r.Type__c != null ? assignment.Lesson__r.Type__c.toLowerCase() : 'lesson';
                    item.title = assignment.Lesson__r.Lesson_Name__c;
                    
                    // Conditionally swap module code and name based on metadata
                    String moduleCode = assignment.Enrollment__r.Module_Assignment__r.Module__r.Name;
                    String moduleName = assignment.Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c;
                    
                    if (useModuleCode) {
                        // When true: use Module_Name__c for item subtitle
                        item.subtitle = 'Module: ' + (moduleName != null ? moduleName : '');
                    } else {
                        // When false (default): use Module Code (Name field) for item subtitle
                        item.subtitle = 'Module: ' + (moduleCode != null ? moduleCode : '');
                    }
                    
                    item.dueDate = ''; // You can add due date if available
                    item.points = assignment.Lesson__r.Lesson_Points__c != null ? Integer.valueOf(assignment.Lesson__r.Lesson_Points__c) : 0;
                    item.isCompleted = assignment.Completed__c;
                    item.lessonId = assignment.Lesson__c;
                    item.assignmentId = assignment.Id;
                    item.quizCount = quizCounts.get(assignment.Lesson__c);
                    
                    // Add navigation IDs for lesson navigation
                    item.courseId = assignment.Enrollment__r.Module_Assignment__r.Module__c; // Using module as course
                    item.moduleId = assignment.Enrollment__r.Module_Assignment__r.Module__c;
                    item.enrollmentId = assignment.Enrollment__c;
                    item.moduleAssignmentId = assignment.Enrollment__r.Module_Assignment__c;
                    
                    // Debug logging to verify IDs are being set
                    System.debug('Timeline item created - moduleId: ' + item.moduleId + ', enrollmentId: ' + item.enrollmentId + ', moduleAssignmentId: ' + item.moduleAssignmentId);
                    
                    weekData.items.add(item);
                }
                
                timelineData.weeks.add(weekData);
            }
            
            return timelineData;
            
        } catch (Exception e) {
            System.debug('Error in getTimelineData: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving timeline data: ' + e.getMessage());
        }
    }
    
    private static String getWeekSubtitle(String week, List<LMS_Lesson_Week_Assignment__c> assignments) {
        if (assignments.isEmpty()) {
            return '';
        }
        
        // Check if we should use module code
        Boolean useModuleCode = CommunityVisibilityHelper.shouldUseModuleCode();
        
        String moduleCode = assignments[0].Enrollment__r.Module_Assignment__r.Module__r.Name;
        String moduleName = assignments[0].Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c;
        
        if (useModuleCode) {
            // When true: use Module Code (Name field) for week subtitle
            return moduleCode != null ? moduleCode : '';
        } else {
            // When false (default): use Module_Name__c for week subtitle
            return moduleName != null ? moduleName : '';
        }
    }
    
    /**
     * Helper method to count quizzes per lesson (reused from MyProgramLessonsController)
     */
    private static Map<Id, Integer> getQuizCounts(Set<Id> lessonIds) {
        Map<Id, Integer> quizCounts = new Map<Id, Integer>();
        
        if (lessonIds.isEmpty()) {
            return quizCounts;
        }
        
        // Query quiz counts per lesson
        List<AggregateResult> quizResults = [
            SELECT Lesson__c, COUNT(Id) quizCount
            FROM LMS_Survey__c 
            WHERE Lesson__c IN :lessonIds
            AND Survey_Type__c = 'Quiz'
            AND Status__c = 'Ready'
            GROUP BY Lesson__c
        ];
        
        // Build the map
        for (AggregateResult result : quizResults) {
            Id lessonId = (Id) result.get('Lesson__c');
            Integer count = (Integer) result.get('quizCount');
            quizCounts.put(lessonId, count);
        }
        
        // Ensure all lessons have an entry (default to 0)
        for (Id lessonId : lessonIds) {
            if (!quizCounts.containsKey(lessonId)) {
                quizCounts.put(lessonId, 0);
            }
        }
        
        return quizCounts;
    }
    
    /**
     * Helper method to fetch labels from ERF_Label__mdt custom metadata
     */
    private static Map<String, String> getErfLabels() {
        Map<String, String> labelMap = new Map<String, String>();
        
        try {
            List<ERF_Label__mdt> labels = [
                SELECT DeveloperName, Value__c
                FROM ERF_Label__mdt
                WHERE DeveloperName IN ('Journey', 'Week')
            ];
            
            for (ERF_Label__mdt label : labels) {
                labelMap.put(label.DeveloperName, label.Value__c);
            }
        } catch (Exception e) {
            System.debug('Error fetching ERF labels: ' + e.getMessage());
            // Return empty map if error occurs, will use default values
        }
        
        return labelMap;
    }
    
    // Data structures for timeline
    public class TimelineData {
        @AuraEnabled public String journeyName { get; set; }
        @AuraEnabled public String journeyLabel { get; set; }
        @AuraEnabled public String weekLabel { get; set; }
        @AuraEnabled public List<WeekData> weeks { get; set; }
        @AuraEnabled public Boolean isEmpty { get; set; }
        @AuraEnabled public String emptyStateMessage { get; set; }
        
        public TimelineData() {
            this.weeks = new List<WeekData>();
            this.isEmpty = false;
        }
    }
    
    public class WeekData {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public Boolean isExpanded { get; set; }
        @AuraEnabled public List<TimelineItemData> items { get; set; }
        
        public WeekData() {
            this.items = new List<TimelineItemData>();
        }
    }
    
    public class TimelineItemData {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public String dueDate { get; set; }
        @AuraEnabled public Integer points { get; set; }
        @AuraEnabled public Boolean isCompleted { get; set; }
        @AuraEnabled public String lessonId { get; set; }
        @AuraEnabled public String assignmentId { get; set; }
        @AuraEnabled public Integer quizCount { get; set; }
        @AuraEnabled public String courseId { get; set; }
        @AuraEnabled public String moduleId { get; set; }
        @AuraEnabled public String enrollmentId { get; set; }
        @AuraEnabled public String moduleAssignmentId { get; set; }
    }
    
    public class JourneyOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
    }
    
    /**
     * Check if Week Count should be visible
     * @return Boolean - Returns true to show week count
     */
    @AuraEnabled
    public static Boolean isWeekCountVisible() {
        System.debug('isWeekCountVisible method called from JourneyOverviewController');
        return true;
    }

    /**
     * Returns timeline data for a given journey, grouped by Module instead of by Week.
     * Reuses the same TimelineData/WeekData/TimelineItemData wrappers — each "WeekData"
     * represents one module.
     */
    @AuraEnabled(cacheable=true)
    public static TimelineData getTimelineDataByModule(Id journeyId) {
        try {
            Map<String, String> labels = getErfLabels();
            Id currentUserId = UserInfo.getUserId();
            Boolean isMemberOrNone = isContactMemberOrNone();
            Boolean useModuleCode = CommunityVisibilityHelper.shouldUseModuleCode();

            List<LMS_Lesson_Week_Assignment__c> assignments;

            if (isMemberOrNone) {
                Id currentContactId = getCurrentUserContactId();
                assignments = [
                    SELECT Id,
                           Lesson__c,
                           Lesson__r.Lesson_Name__c,
                           Lesson__r.Lesson_Points__c,
                           Lesson__r.Type__c,
                           Completed__c,
                           Enrollment__c,
                           Enrollment__r.Journey__c,
                           Enrollment__r.Journey__r.Journey_Name__c,
                           Enrollment__r.Module_Assignment__c,
                           Enrollment__r.Module_Assignment__r.Module__c,
                           Enrollment__r.Module_Assignment__r.Module__r.Name,
                           Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Enrollment__r.External_Resource__c = :currentContactId
                    AND Enrollment__r.Journey__c = :journeyId
                    AND Enrollment__r.Status__c != 'Unenrolled'
                    ORDER BY Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c ASC,
                             Lesson__r.Lesson_Name__c ASC
                ];
            } else {
                assignments = [
                    SELECT Id,
                           Lesson__c,
                           Lesson__r.Lesson_Name__c,
                           Lesson__r.Lesson_Points__c,
                           Lesson__r.Type__c,
                           Completed__c,
                           Enrollment__c,
                           Enrollment__r.Journey__c,
                           Enrollment__r.Journey__r.Journey_Name__c,
                           Enrollment__r.Module_Assignment__c,
                           Enrollment__r.Module_Assignment__r.Module__c,
                           Enrollment__r.Module_Assignment__r.Module__r.Name,
                           Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Enrollment__r.Employee__r.User__c = :currentUserId
                    AND Enrollment__r.Journey__c = :journeyId
                    AND Enrollment__r.Status__c != 'Unenrolled'
                    ORDER BY Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c ASC,
                             Lesson__r.Lesson_Name__c ASC
                ];
            }

            if (assignments.isEmpty()) {
                TimelineData empty = new TimelineData();
                empty.journeyName = getJourneyName(journeyId);
                empty.journeyLabel = labels.get('Journey') != null ? labels.get('Journey') : 'My Journey';
                empty.weekLabel = 'Module';
                empty.weeks = new List<WeekData>();
                empty.isEmpty = true;
                empty.emptyStateMessage = 'No lesson assignments found for this journey. You may need to be enrolled in modules for this journey first.';
                return empty;
            }

            // Collect lesson IDs for quiz counts
            Set<Id> lessonIds = new Set<Id>();
            for (LMS_Lesson_Week_Assignment__c a : assignments) {
                lessonIds.add(a.Lesson__c);
            }
            Map<Id, Integer> quizCounts = getQuizCounts(lessonIds);

            // Group assignments by module, preserving insertion order for display
            Map<String, List<LMS_Lesson_Week_Assignment__c>> moduleMap = new Map<String, List<LMS_Lesson_Week_Assignment__c>>();
            Map<String, String> moduleTitle  = new Map<String, String>(); // primary display name
            Map<String, String> moduleSubtitle = new Map<String, String>(); // secondary display name
            String journeyName = '';

            for (LMS_Lesson_Week_Assignment__c a : assignments) {
                String modId = a.Enrollment__r.Module_Assignment__r.Module__c;
                if (modId == null) modId = 'Unassigned';

                if (!moduleMap.containsKey(modId)) {
                    moduleMap.put(modId, new List<LMS_Lesson_Week_Assignment__c>());
                    String modCode = a.Enrollment__r.Module_Assignment__r.Module__r.Name;
                    String modName = a.Enrollment__r.Module_Assignment__r.Module__r.Module_Name__c;
                    // Primary title: same logic as week subtitle in the original method
                    if (useModuleCode) {
                        moduleTitle.put(modId, modCode != null ? modCode : '');
                        moduleSubtitle.put(modId, modName != null ? modName : '');
                    } else {
                        moduleTitle.put(modId, modName != null ? modName : (modCode != null ? modCode : ''));
                        moduleSubtitle.put(modId, modCode != null ? modCode : '');
                    }
                }
                moduleMap.get(modId).add(a);

                if (String.isBlank(journeyName) && a.Enrollment__r.Journey__r.Journey_Name__c != null) {
                    journeyName = a.Enrollment__r.Journey__r.Journey_Name__c;
                }
            }

            TimelineData timelineData = new TimelineData();
            timelineData.journeyName = journeyName;
            timelineData.journeyLabel = labels.get('Journey') != null ? labels.get('Journey') : 'My Journey';
            timelineData.weekLabel = 'Module';
            timelineData.weeks = new List<WeekData>();

            Boolean isFirst = true;
            for (String modId : moduleMap.keySet()) {
                WeekData mod = new WeekData();
                mod.id = 'module' + modId.replaceAll('[^a-zA-Z0-9]', '');
                mod.title = moduleTitle.get(modId);
                mod.subtitle = moduleSubtitle.get(modId);
                mod.isExpanded = isFirst;
                mod.items = new List<TimelineItemData>();
                isFirst = false;

                for (LMS_Lesson_Week_Assignment__c a : moduleMap.get(modId)) {
                    TimelineItemData item = new TimelineItemData();
                    item.id = a.Id;
                    item.type = a.Lesson__r.Type__c != null ? a.Lesson__r.Type__c.toLowerCase() : 'lesson';
                    item.title = a.Lesson__r.Lesson_Name__c;
                    item.subtitle = '';
                    item.dueDate = '';
                    item.points = a.Lesson__r.Lesson_Points__c != null ? Integer.valueOf(a.Lesson__r.Lesson_Points__c) : 0;
                    item.isCompleted = a.Completed__c;
                    item.lessonId = a.Lesson__c;
                    item.assignmentId = a.Id;
                    item.quizCount = quizCounts.get(a.Lesson__c);
                    item.courseId = a.Enrollment__r.Module_Assignment__r.Module__c;
                    item.moduleId = a.Enrollment__r.Module_Assignment__r.Module__c;
                    item.enrollmentId = a.Enrollment__c;
                    item.moduleAssignmentId = a.Enrollment__r.Module_Assignment__c;
                    mod.items.add(item);
                }

                timelineData.weeks.add(mod);
            }

            return timelineData;

        } catch (Exception e) {
            System.debug('Error in getTimelineDataByModule: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving timeline data by module: ' + e.getMessage());
        }
    }
}