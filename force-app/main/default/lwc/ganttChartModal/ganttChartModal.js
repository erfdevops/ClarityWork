import { LightningElement, api, track } from 'lwc';
import { refreshTab } from 'lightning/platformWorkspaceApi';
import getEmployeesJson from '@salesforce/apex/GanttChartController.getEmployeesJson';
import createNewTask from '@salesforce/apex/GanttChartController.createNewTask';

export default class GanttChartModal extends LightningElement {

    @api stageId;
    @api stageStartDate;
    @api stageEndDate;
    @api parentTabId;
    @track isOpen = false;
    @track employeeList = [];
    @track minDateError = false;
    @track maxDateError = false;
    @track newTask = {
        name: '',
        start_date: '',
        end_date: '',
        ownership: ''
    }

    connectedCallback() {
        this.getEmployeeList();
    }

    getEmployeeList() {
        getEmployeesJson({ })
        .then(result => {
            this.employeeList = JSON.parse(result);
        })
        .catch(error => {
            console.log('Error: ' + JSON.stringify(error));
        });
    }

    generateNewTask() {
        createNewTask({ taskName: this.newTask.name, stageId: this.stageId, startDate: this.newTask.start_date, endDate: this.newTask.end_date, assignedTo: this.newTask.ownership })
        .then(result => {
            console.log('NEW TASK: ' + result);
        })
        .catch(error => {
            console.log('Error: ' + JSON.stringify(error));
        });
    }

    @api openModal() {
        this.isOpen = true;
    }

    @api closeModal() {
        this.isOpen = false;
    }

    handleChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        
        if (field === 'name') {
            this.newTask.name = value;
        } else if (field === 'selectEmployee') {
            this.newTask.ownership = value;
        } else if (field === 'startdate') {
            this.newTask.start_date = value;
        } else if (field === 'enddate') {
            this.newTask.end_date = value;
        }
    }

    handleSave() {
        this.generateNewTask();
        setTimeout(() => {
            this.refreshParentTab();
            this.closeModal();
        }, 1000);
    }

    refreshParentTab() {
        refreshTab(this.parentTabId, {
            includeAllSubtabs: true
        });
    }
}