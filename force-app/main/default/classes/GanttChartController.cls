/**
 * @description       : This class is the Controller for the Gantt Chart Lwc
 * @author            : Pablo Castro 07-16-2025
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : Pablo Castro
**/

public with sharing class GanttChartController {

    @AuraEnabled
    public static String getInitiativeJson(String initiativeId, String objectApiName) {
        String jsonData = '';
        Initiative__c currentInitiative = new Initiative__c();
        Benefit__c currentDeathBenefit = new Benefit__c();
        Map<String, Object> recordDataMap = new Map<String, Object>();
        String soqlQuerySentence = 'SELECT Id, Initiative_Name__c, Name, Start_Date__c, End_Date__c, Status__c FROM ' + objectApiName + ' WHERE Id = \'' + initiativeId + '\'';
        //System.debug('>>> getInitiativeJson >>> ' + soqlQuerySentence);

        try {
            if (objectApiName == 'Initiative__c') {
                currentInitiative = Database.query(soqlQuerySentence);
                recordDataMap.put('id', currentInitiative.Id);
                recordDataMap.put('name', currentInitiative.Initiative_Name__c);
                recordDataMap.put('start_date', convertDateToJsonFormat(currentInitiative.Start_Date__c));
                recordDataMap.put('end_date', convertDateToJsonFormat(currentInitiative.End_Date__c));
                recordDataMap.put('status', currentInitiative.Status__c);
                recordDataMap.put('statusCss', getCssClassForStatus(currentInitiative.Status__c));
            } else if (objectApiName == 'Benefit__c') {
                currentDeathBenefit = Database.query(soqlQuerySentence);
                recordDataMap.put('id', currentDeathBenefit.Id);
                recordDataMap.put('name', currentDeathBenefit.Name);
                recordDataMap.put('start_date', convertDateToJsonFormat(currentDeathBenefit.Start_Date__c));
                recordDataMap.put('end_date', convertDateToJsonFormat(currentDeathBenefit.End_Date__c));
                recordDataMap.put('status', currentDeathBenefit.Status__c);
                recordDataMap.put('statusCss', getCssClassForStatus(currentDeathBenefit.Status__c));
            }

            jsonData = JSON.serialize(recordDataMap);
        } catch (Exception erex) {
            System.debug('Error on GanttChartController.getInitiativeData - ' + erex.getMessage());
            throw new AuraHandledException(erex.getMessage());
        }

        return jsonData;
    }

    @AuraEnabled
    public static String getGanttChartJson(String initiativeId, String objectApiName) {
        String jsonData = '';
        List<Map<String, Object>> StagesList = new List<Map<String, Object>>();

        //String soqlQuerySentence = 'SELECT Id, Name, Start_Date__c, End_Date__c, Status__c, Employee__r.Name, SMART_Goal_Achievement__c FROM Initiative_Stage__c WHERE ' + objectApiName + ' = \'' + initiativeId + '\' ORDER BY Start_Date__c ASC';
        String soqlQuerySentence = 'SELECT Id, Name, Start_Date__c, Completed_Date__c, Status__c, Employee__r.Name, SMART_Goal_Achievement__c FROM Initiative_Stage__c WHERE ' + objectApiName + ' = \'' + initiativeId + '\' ORDER BY Start_Date__c ASC';
        List<Initiative_Stage__c> stagesQuery = Database.query(soqlQuerySentence);

        for (Initiative_Stage__c Stage : stagesQuery) {
            //System.debug(milestone.Name + ' - ' + milestone.Start_Date__c + ' - ' + milestone.End_Date__c + ' - ' + milestone.Status__c);
            Decimal tasksTotalAmount = 0;
            Decimal tasksCompletedAmount = 0; 
            Decimal stageCompletionPercentage = 0;
            Map<String, Object> StageMap = new Map<String, Object>();
            StageMap.put('id', Stage.Id);
            StageMap.put('name', Stage.Name);
            StageMap.put('status', Stage.Status__c);
            StageMap.put('start_date', convertDateToJsonFormat(Stage.Start_Date__c));
            StageMap.put('end_date', convertDateToJsonFormat(Stage.Completed_Date__c));
            StageMap.put('ownership', Stage.Employee__r.Name);
            StageMap.put('smart_goal_achievement', Stage.SMART_Goal_Achievement__c);
            StageMap.put('statusCss', getCssClassForStatus(Stage.Status__c));
            //StageMap.put('action', '');

            List<Map<String, Object>> tasksList = new List<Map<String, Object>>();
            for (Initiative_Task__c task : [SELECT Id, Name, Due_Date__c, Completion_Date__c, Start_Date__c, Assigned_to__r.Name, Status__c FROM Initiative_Task__c WHERE Stage__c = :Stage.Id ORDER BY Due_Date__c ASC]) {
                //System.debug(' > ' + task.Name + ' - ' + task.Due_Date__c + ' - ' + task.Completion_Date__c + ' - ' + task.Status__c);
                Map<String, Object> taskMap = new Map<String, Object>();
                Decimal taskCompletionPercentage = 0;
                Boolean checkedStatus = false;
                if (task.Status__c != '' && task.Status__c == 'Completed') {
                    checkedStatus = true;
                }

                taskMap.put('id', task.Id);
                taskMap.put('name', task.Name);
                taskMap.put('status', task.Status__c);
                taskMap.put('ownership', task.Assigned_to__r.Name);
                taskMap.put('start_date', convertDateToJsonFormat(task.Start_Date__c));
                taskMap.put('end_date', convertDateToJsonFormat(task.Completion_Date__c));
                taskMap.put('due_date', convertDateToJsonFormat(task.Due_Date__c));
                taskMap.put('checked', checkedStatus);
                taskMap.put('action', '');
                taskMap.put('statusCss', getCssClassForStatus(task.Status__c));
                
                tasksTotalAmount++;
                if (task.Status__c == 'Completed') {
                    tasksCompletedAmount++;
                    taskCompletionPercentage = 100;
                }

                taskMap.put('completion_percentage', taskCompletionPercentage);
                tasksList.add(taskMap);
            }

            System.debug('Stage: ' + Stage.Name);
            System.debug('tasksTotalAmount: ' + tasksTotalAmount);
            System.debug('tasksCompletedAmount' + tasksCompletedAmount);

            if (tasksTotalAmount > 0) {
                stageCompletionPercentage = (tasksCompletedAmount / tasksTotalAmount) * 100;
            }
            
            StageMap.put('completion_percentage', stageCompletionPercentage.round(System.RoundingMode.DOWN));
            StageMap.put('tasks', tasksList);
            StagesList.add(StageMap);

        }

        jsonData = JSON.serialize(StagesList);
        return jsonData;
    }

    @AuraEnabled
    public static String getEmployeesJson() {
        List<Map<String, Object>> employeeList = new List<Map<String, Object>>();
        String jsonData = '';

        for (Employee__c employee : [SELECT Id, Name FROM Employee__c]) {
            Map<String, Object> employeeMap = new Map<String, Object>();
            employeeMap.put('id', employee.Id);
            employeeMap.put('name', employee.Name);
            employeeList.add(employeeMap);
        }

        jsonData = JSON.serialize(employeeList);
        return jsonData;
    }

    @AuraEnabled
    //public static void createNewTask(String taskName, String milestoneId, String startDate, String endDate, String assignedTo) {
    public static void createNewTask(String taskName, String stageId, String startDate, String dueDate, String assignedTo) {
        System.debug('*** createNewTask ***');
        System.debug(taskName + ' - ' + stageId + ' - ' + startDate + ' - ' + dueDate + ' - ' + assignedTo);

        try {
            Initiative_Task__c newTask = new Initiative_Task__c();
            newTask.Name = taskName;
            newTask.Stage__c = stageId;
            newTask.Start_Date__c = Date.valueOf(startDate);
            newTask.Due_Date__c = Date.valueOf(dueDate);
            newTask.Status__c = 'Not Started';
            newTask.Assigned_to__c = assignedTo;

            insert newTask;
        } catch (Exception erex) {
            System.debug('Error on GanttChartController.getInitiativeData - ' + erex.getMessage());
            throw new AuraHandledException(erex.getMessage());
        }   
    }

    public static String getCssClassForStatus(String statusCode) {
        String cssClass = '';
        if (statusCode == 'In Progress') {
            cssClass = 'status-inprogress';
        } else if (statusCode == 'Completed') {
            cssClass = 'status-completed';
        } else if (statusCode == 'Pending' || statusCode == 'Cancelled') {
            cssClass = 'status-pending';
        } else if (statusCode == 'On Hold' || statusCode == 'Not Started') {
            cssClass = 'status-review';
        } else if (statusCode == 'Behind') {
            cssClass = 'status-behind';
        }
        return cssClass;
    }

    public static String convertDateToJsonFormat(Date dateToConvert) {
        String formattedDate = '';
        if (dateToConvert != null) {
            formattedDate = dateToConvert.format();
        }
        return formattedDate;
    }
}