public without sharing class JourneyModuleAssignmentController {

    public class JourneyData {
        @AuraEnabled public String journeyId;
        @AuraEnabled public String journeyName;
        @AuraEnabled public List<ModuleData> modules;
    }

    public class ModuleData {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String moduleName;
        @AuraEnabled public Boolean isAssigned;
    }

    @AuraEnabled(cacheable=true)
    public static JourneyData getJourneyWithModules(Id journeyId) {
        JourneyData result = new JourneyData();

        LMS_Journey__c journey = [
            SELECT Id, Journey_Name__c, Start_Date__c, End_Date__c
            FROM LMS_Journey__c
            WHERE Id = :journeyId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        result.journeyId = journey.Id;
        result.journeyName = journey.Journey_Name__c;

        // Collect modules already assigned to this journey
        Set<Id> alreadyAssignedIds = new Set<Id>();
        for (LMS_Module_Assignment__c existing : [
            SELECT Module__c
            FROM LMS_Module_Assignment__c
            WHERE Journey__c = :journeyId
            WITH SECURITY_ENFORCED
        ]) {
            alreadyAssignedIds.add(existing.Module__c);
        }

        List<LMS_Module__c> modules = [
            SELECT Id, Name, Module_Name__c
            FROM LMS_Module__c
            WHERE Publishing_Status__c = 'Published'
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
        ];

        result.modules = new List<ModuleData>();
        for (LMS_Module__c m : modules) {
            ModuleData md = new ModuleData();
            md.id = m.Id;
            md.name = m.Name;
            md.moduleName = m.Module_Name__c;
            md.isAssigned = alreadyAssignedIds.contains(m.Id);
            result.modules.add(md);
        }

        return result;
    }

    @AuraEnabled
    public static void createModuleAssignments(Id journeyId, List<Id> moduleIds) {
        LMS_Journey__c journey = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Journey__c
            WHERE Id = :journeyId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        Map<Id, LMS_Module__c> moduleMap = new Map<Id, LMS_Module__c>([
            SELECT Id, Name, Module_Name__c
            FROM LMS_Module__c
            WHERE Id IN :moduleIds
            WITH SECURITY_ENFORCED
        ]);

        List<LMS_Module_Assignment__c> assignments = new List<LMS_Module_Assignment__c>();
        for (Id moduleId : moduleIds) {
            LMS_Module__c mod = moduleMap.get(moduleId);
            String moduleName = (mod != null && String.isNotBlank(mod.Module_Name__c))
                ? mod.Module_Name__c
                : (mod != null ? mod.Name : '');
            assignments.add(new LMS_Module_Assignment__c(
                Journey__c = journeyId,
                Module__c = moduleId,
                Assignment_Name__c = moduleName + ' Assignment',
                Start_Date__c = journey.Start_Date__c,
                End_Date__c = journey.End_Date__c
            ));
        }
        insert assignments;
    }
}