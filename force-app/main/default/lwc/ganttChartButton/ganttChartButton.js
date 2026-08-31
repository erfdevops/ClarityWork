import { LightningElement, wire, api } from 'lwc';
import { EnclosingTabId, getTabInfo, openSubtab } from 'lightning/platformWorkspaceApi';

export default class GanttChartButton extends LightningElement {

    @wire(EnclosingTabId) enclosingTabId;
    @api recordId;
    @api objectName;

    connectedCallback() {
        this.getTabInformation();
    }

    getTabInformation() {
        if (this.enclosingTabId) {
            getTabInfo(this.enclosingTabId).then((tabInfo) => {
                this.recordId = tabInfo.pageReference.attributes.recordId;
                this.objectName = tabInfo.pageReference.attributes.objectApiName;
            }).catch((error) => {
                console.log('ERROR: ' + error);
            });
        }
    }

    openGanttChartTab() {
        openSubtab(this.enclosingTabId, {
            pageReference: {
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Gantt_Chart',
                    c__recordId: this.recordId,
                    c__sobject: this.objectName,
                    c__enclosingTabId: this.enclosingTabId
                }
            },
            icon: 'utility:bookmark',
            focus: true,
            label: 'Gantt Chart'
        });
    }
}