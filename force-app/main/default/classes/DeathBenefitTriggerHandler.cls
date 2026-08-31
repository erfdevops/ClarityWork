/**
 * @description       : This class is the Trigger Handler for the Initiative Task object
 * @author            : Pablo Castro 08-13-2025
 * @group             : 
 * @last modified on  : 08-14-2025
 * @last modified by  : Pablo Castro
**/

public class DeathBenefitTriggerHandler {

    public static Boolean triggerExecutionFlag = false;

    public static void run(Map<Id, Death_Benefit__c> oldMap, List<Death_Benefit__c> newList) {
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

    public static void handleBeforeInsert(List<Death_Benefit__c> newList) {     
        DeathBenefitTriggerHelper.templateMethodForTrigger(newList, 'Before Insert');
    }

    public static void handleBeforeUpdate(List<Death_Benefit__c> newList, Map<Id, Death_Benefit__c> oldMap) {      
        DeathBenefitTriggerHelper.templateMethodForTrigger(newList, 'Before Update');
    }

    public static void handleAfterInsert(List<Death_Benefit__c> newList) {
        DeathBenefitTriggerHelper.templateMethodForTrigger(newList, 'After Insert');
    }

    public static void handleAfterUpdate(List<Death_Benefit__c> newList, Map<Id, Death_Benefit__c> oldMap) {      
        DeathBenefitTriggerHelper.templateMethodForTrigger(newList, 'After Update');
    }
}