import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
//import { openSubtab, EnclosingTabId, IsConsoleNavigation, setTabLabel, setTabIcon } from 'lightning/platformWorkspaceApi';
import { openSubtab } from 'lightning/platformWorkspaceApi';
import getInitiativeJson from '@salesforce/apex/GanttChartController.getInitiativeJson';
import getGanttChartJson from '@salesforce/apex/GanttChartController.getGanttChartJson';

export default class GanttChart extends LightningElement {

    @api newTaskId = 'new-task-id';
    @track initiativeId;
    @track sobjectApiName;
    @track enclosingTabId;
    @track initiative = {};
    @track stages = [];
    @track newTaskStatus = false;
    @track daysAmount = 0;
    @track daysArray = [];
    @track monthsArray = [];
    @track datesJson = [];
    scrollListenersAdded = false;
    monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    //@wire(EnclosingTabId) enclosingTabId;
    //@wire(IsConsoleNavigation) isConsoleNavigation;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.attributes.c__recordId) {
            this.initiativeId = pageRef.attributes.c__recordId;
            this.sobjectApiName = pageRef.attributes.c__sobject;
            this.enclosingTabId = pageRef.attributes.c__enclosingTabId;
        }
    }
    
    connectedCallback() {
        this.getInitiativeData();
        this.getMilestonesAndTasks();
    }

    renderedCallback() {
        //this.setTabInformation();
        this.syncContainersScrolling();
    }

    getInitiativeData() {
        getInitiativeJson({ initiativeId: this.initiativeId, objectApiName: this.sobjectApiName })
        .then(result => {
            this.initiative = JSON.parse(result);
        })
        .catch(error => {
            console.log('Error: ' + JSON.stringify(error));
        });
    }

    getMilestonesAndTasks() {
        getGanttChartJson({ initiativeId: this.initiativeId, objectApiName: this.sobjectApiName })
        .then(result => {
            this.stages = JSON.parse(result);
            //console.table(result);
            this.setCalendarHeader();
            this.setCalendarBody(); 
        })
        .catch(error => {
            console.log('Error: ' + JSON.stringify(error));
        });
    }

    setCalendarHeader() {
        const oneDay = 24 * 60 * 60 * 1000;
        const startDate = new Date(this.initiative.start_date);
        const endDate = new Date(this.initiative.end_date);
        this.daysAmount = Math.round(Math.abs(endDate - startDate)/oneDay);

        let indexMonths = 0;
        let daysPerMonth = 0;
        let previousMonth = '';
        for (let i = 0; i <= this.daysAmount; i++) {
            let dateValue = new Date(this.initiative.start_date);
            dateValue.setDate(startDate.getDate() + i);
            let dayKey = 'hday-' + i;
            this.daysArray[i] = { id: dayKey, number: dateValue.getDate() };
            
            let currentMonth = dateValue.getMonth();
            let monthId = this.monthNames[previousMonth] + '-' + dateValue.getMonth() + '-' +  1;
            if (previousMonth == '') {
                previousMonth = dateValue.getMonth();
            } else if (previousMonth != '' && previousMonth != currentMonth) {
                this.monthsArray[indexMonths] = { id: monthId, name: this.monthNames[previousMonth], colspan: daysPerMonth};
                previousMonth = currentMonth;
                daysPerMonth = 0;
                indexMonths++;
            } else if (previousMonth != '' && previousMonth == currentMonth && i == this.daysAmount) {
                daysPerMonth++;
                this.monthsArray[indexMonths] = { id: monthId, name: this.monthNames[previousMonth], colspan: daysPerMonth};
            }
            daysPerMonth++;
        }
    }

    setCalendarBody() {
        for (let i = 0; i < this.stages.length; i++) {
            const stageStartDate = new Date(this.stages[i].start_date);
            const stageEndDate = new Date(this.stages[i].end_date);
            const stageStatusCss = 'date-' + this.stages[i].statusCss;

            let stageKey = 'stage-' + i;
            let daysPerStage = this.generateDaysBarArray(stageStartDate, stageEndDate, '', stageStatusCss, stageKey);
            this.stages[i]['days'] = daysPerStage;
            
            for (let j = 0; j < this.stages[i].tasks.length; j++) {
                const taskStartDate = new Date(this.stages[i].tasks[j].start_date);
                const taskEndDate = new Date(this.stages[i].tasks[j].end_date);
                const taskDueDate = new Date(this.stages[i].tasks[j].due_date);
                const taskStatusCss = 'date-' + this.stages[i].tasks[j].statusCss;

                let taskKey = 'task-' + i + '-' + j;
                let daysPerTask = this.generateDaysBarArray(taskStartDate, taskEndDate, taskDueDate, taskStatusCss, taskKey);
                this.stages[i].tasks[j]['days'] = daysPerTask;
            }
        }
    }

    generateDaysBarArray(startDate, endDate, dueDate, cssClass, indexKey) {
        const initiativeStartDate = new Date(this.initiative.start_date);
        let daysPerItem = [];

        for (let k = 0; k <= this.daysAmount; k++) {
            let dateValue = new Date(this.initiative.start_date);
            dateValue.setDate(initiativeStartDate.getDate() + k);
            let dayKey = indexKey + '-' + k;

            let wrapperCssClass = 'date-status-wrapper';
            if (dateValue.getDay() >= 1 && dateValue.getDay() <= 5) {
                wrapperCssClass = 'date-status-wrapper-weekday';
            }

            let jsonTask = {key: dayKey, title: '', dueDateStatus: false, statusCss: '', wrapperCss: wrapperCssClass, flag: false};
            if (dateValue.getTime() >= startDate.getTime() && dateValue.getTime() <= endDate.getTime()) {
                let cssClassBar = cssClass;
                if (dateValue.getTime() == startDate.getTime()) { cssClassBar = cssClass + ' date-status-start'; }
                if (dateValue.getTime() == endDate.getTime()) { cssClassBar = cssClass + ' date-status-end'; }
                jsonTask = {key: dayKey, title: '', dueDateStatus: false, statusCss: cssClassBar, wrapperCss: wrapperCssClass, flag: true};
            }

            if (dueDate != '' && dateValue.getTime() == dueDate.getTime()) {
                jsonTask.dueDateStatus = true;
            }
            daysPerItem.push(jsonTask);
        }

        return daysPerItem;
    }
    
    toggleTasks(event) {
        const stageId = event.currentTarget.dataset.id;
        for (let i = 0; i <= this.stages.length; i++) {
            if (this.stages[i].id == stageId) {
                this.stages[i].toggleTasks = !this.stages[i].toggleTasks;
            }
        }
    }

    addNewTask(event) {
        const childComponent = this.template.querySelector('c-gantt-chart-modal-new-task');
        const stageId = event.currentTarget.dataset.stageid;
        const startDate = event.currentTarget.dataset.startdate;
        const endDate = event.currentTarget.dataset.enddate;

        childComponent.openModal();
        childComponent.stageId = stageId;
        childComponent.stageStartDate = startDate;
        childComponent.stageEndDate = endDate;
        childComponent.parentTabId = this.enclosingTabId;
    }

    syncContainersScrolling() {
        const containerLeft = this.template.querySelector('.body-container-left');
        const containerRight = this.template.querySelector('.body-container-right');

        if (containerLeft && containerRight && !this.scrollListenersAdded) {
            containerLeft.addEventListener('scroll', () => {
                containerRight.scrollTop = containerLeft.scrollTop;
            });

            containerRight.addEventListener('scroll', () => {
                containerLeft.scrollTop = containerRight.scrollTop;
            });

            this.scrollListenersAdded = true;
        }
    }

    openRecordViewInSubTab(event) {
        const selectedRecordId = event.currentTarget.dataset.recordid;
        const selectedRecordName = event.currentTarget.dataset.recordname;
        const selectedRecordType = event.currentTarget.dataset.recordtype;
        let recordUtilityIcon = 'utility:record';

        if (selectedRecordType == 'task') {
            recordUtilityIcon = 'utility:record_collection';
        } else if (selectedRecordType == 'stage') {
            recordUtilityIcon = 'utility:record_alt';
        }

        openSubtab(this.enclosingTabId, {
            recordId: selectedRecordId,
            focus: true,
            label: selectedRecordName,
            icon: recordUtilityIcon
        });
    }

    /*
    setTabInformation() {
        if (!this.isConsoleNavigation) {
            return;
        } else {
            setTabLabel(this.enclosingTabId, 'Gantt Chart TAB TEST').then(() => {
                console.log('Tab label updated successfully');
            }).catch((error) => {
                console.error('Error updating tab label:', error);
            });

            setTabIcon(this.enclosingTabId, 'utility:bookmark', {
                iconAlt: 'Gantt Chart'
            });
        }
    }
    */

    get isRecordInitiative() {
        let statusInitiativeRecord = false;
        if (this.sobjectApiName == 'Initiative__c') {
            statusInitiativeRecord = true;
        }
        return statusInitiativeRecord;
    }
}