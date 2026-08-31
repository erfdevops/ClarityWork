/**
 * @description       : This class is the Trigger Handler for the Initiative Task object
 * @author            : Pablo Castro 08-06-2025
 * @group             : 
 * @last modified on  : 08-06-2025
 * @last modified by  : Pablo Castro
**/

public class InitiativeTaskTriggerHandler {

    public static Boolean triggerExecutionFlag = false;

    public static void run(Map<Id, Initiative_Task__c> oldMap, List<Initiative_Task__c> newList) {
        if (triggerExecutionFlag) { 
            return;
        }

        if (Trigger.isBefore) {
            if (Trigger.isInsert) {
                handleBeforeInsert(newList);
            } else if (Trigger.isUpdate) {
                handleBeforeUpdate(newList, oldMap);
            }
        } else if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                handleAfterInsert(newList);
            } else if (Trigger.isUpdate) {
                handleAfterUpdate(newList, oldMap);
            }
        }
    }

    public static void handleBeforeInsert(List<Initiative_Task__c> newList) {     
        InitiativeTaskTriggerHelper.addInitiativeIdToNewTasks(newList); 
    }

    public static void handleBeforeUpdate(List<Initiative_Task__c> newList, Map<Id, Initiative_Task__c> oldMap) {      
        InitiativeTaskTriggerHelper.templateMethodForTrigger(newList, 'Before Update');
    }

    public static void handleAfterInsert(List<Initiative_Task__c> newList) {
        InitiativeTaskTriggerHelper.templateMethodForTrigger(newList, 'After Insert');
    }

    public static void handleAfterUpdate(List<Initiative_Task__c> newList, Map<Id, Initiative_Task__c> oldMap) {      
        InitiativeTaskTriggerHelper.templateMethodForTrigger(newList, 'After Update');
    }
}