/**
 * @description       : This class is the Trigger Handler for the Initiative Task object
 * @author            : Pablo Castro 08-13-2025
 * @group             : 
 * @last modified on  : 08-14-2025
 * @last modified by  : Pablo Castro
**/

public class InitiativeTaskTriggerHelper {

    public static void templateMethodForTrigger(List<Initiative_Task__c> newList, String executionStep) {
        System.debug('Initiative Task Trigger Handler Execution - ' + executionStep);
        for (Initiative_Task__c newTask : newList) {
            System.debug('> ' + newTask.Name + ' - ' + newTask.Id);
        }
    }

    //NOTE: I need to move this to After Insert and query the records to update them
    public static void addInitiativeIdToNewTasks(List<Initiative_Task__c> newList) {
        System.debug('Initiative Task Trigger Handler Execution: addInitiativeIdToNewTasks [BeforeInsert]');
        for (Initiative_Task__c newTask : newList) {
            if (newTask.Initiative__c == null && newTask.Stage__c != null) {
                newTask.Initiative__c = newTask.Stage__r.Initiative__c;
                System.debug('> ' + newTask.Name + ' - ' + newTask.Id + ' - ' + newTask.Initiative__c);
            }
        }
    }

    /*
    public static void addInitiativeIdToNewTasks(List<Initiative_Task__c> newList) {
        System.debug('Initiative Task Trigger Handler Execution');
        List<Initiative_Task__c> updatedTasksList = new List<Initiative_Task__c>();
        for (Initiative_Task__c newTask : newList) {
            if (newTask.Initiative__c == null) {
                Initiative_Task__c taskToUpdate = new Initiative_Task__c();
                taskToUpdate = newTask;
                taskToUpdate.Initiative__c = newTask.Stage__r.Initiative__c;
                updatedTasksList.add(taskToUpdate);
            }
        }
        update updatedTasksList;
    }
    */
}