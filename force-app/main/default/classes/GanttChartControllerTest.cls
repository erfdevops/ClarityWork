/**
 * @description       : This the Test Class for the Gantt Chart Controller
 * @author            : Pablo Castro 09-22-2025
 * @group             : 
 * @last modified on  : 09-23-2025
 * @last modified by  : Pablo Castro
**/

@isTest
public without sharing class GanttChartControllerTest {

    @testSetup
    static void setupData() {
        List<Employee__c> employees = new List<Employee__c>();
        for (Integer i = 0; i < 2; i++) {
            employees.add(new Employee__c(Name = 'Employee ' + i));
        }
        insert employees;

        Initiative__c init = new Initiative__c(
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(10),
            Status__c = 'In Progress'
        );
        insert init;

        Death_Benefit__c db = new Death_Benefit__c(
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(5),
            Status__c = 'Completed'
        );
        insert db;

        Initiative_Stage__c stage = new Initiative_Stage__c(
            Initiative__c = init.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(3),
            Status__c = 'In Progress'
        );
        insert stage;

        Initiative_Task__c task = new Initiative_Task__c(
            Stage__c = stage.Id,
            Due_Date__c = Date.today(),
            Completion_Date__c = Date.today().addDays(1),
            Status__c = 'Not Started',
            Assigned_to__c = employees[0].Id
        );
        insert task;
    }

    @isTest
    static void testGetInitiativeJson_withInitiative() {
        Initiative__c init = [SELECT Id FROM Initiative__c LIMIT 1];
        String jsonResult = GanttChartController.getInitiativeJson(init.Id, 'Initiative__c');
        Assert.isNotNull(jsonResult, 'Should return JSON string');
        Assert.isNotNull(jsonResult.contains('Test Initiative'), 'JSON should contain initiative name');
    }

    @isTest
    static void testGetInitiativeJson_withDeathBenefit() {
        Death_Benefit__c db = [SELECT Id FROM Death_Benefit__c LIMIT 1];
        String jsonResult = GanttChartController.getInitiativeJson(db.Id, 'Death_Benefit__c');
        Assert.isNotNull(jsonResult, 'Should return JSON string');
    }

    @isTest
    static void testGetGanttChartJson() {
        Initiative__c init = [SELECT Id FROM Initiative__c LIMIT 1];
        String jsonResult = GanttChartController.getGanttChartJson(init.Id, 'Initiative__c');
        Assert.isNotNull(jsonResult, 'Should return JSON string');
        Assert.isNotNull(jsonResult.contains('Stage 1'), 'JSON should contain stage name');
        Assert.isNotNull(jsonResult.contains('Task 1'), 'JSON should contain task name');
    }

    @isTest
    static void testGetEmployeesJson() {
        String jsonResult = GanttChartController.getEmployeesJson();
        Assert.isNotNull(jsonResult, 'Should return JSON string');
        Assert.isNotNull(jsonResult.contains('Employee 0'), 'JSON should contain employee name');
    }

    @isTest
    static void testCreateNewTask() {
        Initiative_Stage__c stage = [SELECT Id FROM Initiative_Stage__c LIMIT 1];
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        GanttChartController.createNewTask(
            'New Task',
            stage.Id,
            '2025-09-01',
            '2025-10-01',
            emp.Id
        );
        Test.stopTest();

        Initiative_Task__c newTask = [SELECT Name, Stage__c, Status__c FROM Initiative_Task__c WHERE Name = 'New Task' LIMIT 1];
        Assert.areEqual('Not Started', newTask.Status__c, 'Task should be created with status Not Started');
    }

    @isTest
    static void testHelperMethods() {
        Assert.areEqual('status-inprogress', GanttChartController.getCssClassForStatus('In Progress'), 'Error message');
        Assert.areEqual('status-completed', GanttChartController.getCssClassForStatus('Completed'), 'Error message');
        Assert.areEqual('status-pending', GanttChartController.getCssClassForStatus('Pending'), 'Error message');
        Assert.areEqual('status-review', GanttChartController.getCssClassForStatus('Not Started'), 'Error message');
        String formattedDate = GanttChartController.convertDateToJsonFormat(Date.today());
        Assert.areNotEqual('', formattedDate, 'Should return formatted date string');
    }
}