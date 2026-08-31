import { LightningElement, api, track, wire } from 'lwc';
import { RefreshEvent } from 'lightning/refresh'; 
import { EnclosingTabId, getTabInfo } from 'lightning/platformWorkspaceApi';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import LightningToast from "lightning/toast";
import getDependentPicklistMap from '@salesforce/apex/CustomPathController.getDependentPicklistMap';
import updateInitiativeStage from '@salesforce/apex/CustomPathController.updateInitiativeStage';
import BENEFIT_SUBTYPE_FIELD from '@salesforce/schema/Benefit__c.Benefit_Sub_Type__c';
import INITIATIVE_STAGE_FIELD from '@salesforce/schema/Benefit__c.Initiative_Stage__c';

export default class CustomPath extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api initiativeStagesMap = [];
    @api previousIndex = 0;
    @api selectedInitiativeStage = '';
    @api currentBenefitSubtypeField = '';
    @api currentInitiativeStageField = '';
    @track initiativeStagesPath = [];
    @wire(EnclosingTabId) enclosingTabId;

    @wire(getRecord, { recordId: "$recordId", fields: [BENEFIT_SUBTYPE_FIELD, INITIATIVE_STAGE_FIELD] })
    benefitRecords;

    @wire(getRecord, { recordId: "$recordId", fields: [BENEFIT_SUBTYPE_FIELD, INITIATIVE_STAGE_FIELD] })
    wiredBenefitRecords(data, error) {
        if (data) {
            if (this.currentBenefitSubtypeField == '') {
                this.currentBenefitSubtypeField = getFieldValue(data, BENEFIT_SUBTYPE_FIELD);
            } else {
                let newBenefitSubtypeField = getFieldValue(data, BENEFIT_SUBTYPE_FIELD);
                if (this.currentBenefitSubtypeField != '' && (this.currentBenefitSubtypeField != newBenefitSubtypeField) && this.initiativeStagesPath != '') {
                    this.createPathObject();
                }
            }

            if (this.currentInitiativeStageField == '') {
                this.currentInitiativeStageField = getFieldValue(data, INITIATIVE_STAGE_FIELD);
            } else {
                let newInitiativeStageField = getFieldValue(data, BENEFIT_SUBTYPE_FIELD);
                if (this.currentInitiativeStageField != '' && (this.currentInitiativeStageField != newInitiativeStageField) && this.initiativeStagesPath != '') {
                    this.createPathObject();
                }
            }
        } else if (error) {
            console.log('Error: ' + JSON.stringify(error));
        }
    }

    connectedCallback() {
        this.getTabInformation();
        this.getDependentPicklists();      
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

    getDependentPicklists() {
        getDependentPicklistMap({ objectApiName: 'Benefit__c', controllingFieldApiName: 'Benefit_Sub_Type__c',  dependentFieldApiName: 'Initiative_Stage__c'})
        .then(result => {
            this.initiativeStagesMap = result;
            this.createPathObject();
        })
        .catch(error => {
            console.log('Error: ' + JSON.stringify(error));
        });
    }

    updateInitiativeStageField() {
        updateInitiativeStage({ benefitRecordId: this.recordId, newInitiativeStageValue: this.selectedInitiativeStage.label })
        .then(result => {
            this.getDependentPicklists();
            this.displayToastSuccess();
            this.dispatchEvent(new RefreshEvent());
        })
        .catch(error => {
            console.log('Error: ' + JSON.stringify(error));
            LightningToast.show({
                label: "An error happened, contact your Admin: " + JSON.stringify(error),
                mode: "sticky",
                variant: "error",
            }, this,);
        });
    }

    createPathObject() {
        let cssColorComplete = 'background-color-complete';
        let cssColorIncomplete = 'background-color-incomplete';
        let cssColorCurrent = 'background-color-current';
        let cssShapeStart = 'stage-circle-start';
        let cssShapeEnd = 'stage-circle-end';
        let cssShapeMid = 'stage-text';
        let dependentPicklistObject = [];
        let currentPicklistValueIndex = 0;
        let dependentPicklistValues = this.initiativeStagesMap[this.benefitSubtypeCurrentValue];
        let currentPicklistValue = getFieldValue(this.benefitRecords.data, INITIATIVE_STAGE_FIELD);

        for (let j = 0; j < dependentPicklistValues.length; j++) {
            let picklistValue = dependentPicklistValues[j];
            if (picklistValue == currentPicklistValue) {
                currentPicklistValueIndex = j;
            }
        }

        for (let i = 0; i < dependentPicklistValues.length; i++) {
            let dependentPicklistValue = dependentPicklistValues[i];
            let lastPosition = dependentPicklistValues.length - 1;
            let itemId = 'stage' + i;

            let cssStyleShape = '';
            if (i == 0) {
                cssStyleShape = cssShapeStart;
            } else if (i == lastPosition) {
                cssStyleShape = cssShapeEnd;
            } else {
                cssStyleShape = cssShapeMid;
            }
            
            let currentStatus = false;
            let completeStatus = false;
            let cssStyleStatusColor = '';
            let cssStyleStageText = 'text-color-white';
            if (i == currentPicklistValueIndex && currentPicklistValue != null) {
                cssStyleStatusColor = cssColorCurrent;
                currentStatus = true;
            } else if (i < currentPicklistValueIndex) {
                completeStatus = true;
                cssStyleStatusColor = cssColorComplete;
            } else {
                cssStyleStageText = 'text-color-black';
                cssStyleStatusColor = cssColorIncomplete;
            }
            
            dependentPicklistObject[i] = { 
                id: itemId, 
                label : dependentPicklistValue, 
                complete: completeStatus,
                showComplete: false,
                current: currentStatus,
                next: false,
                cssStyleText: 'stage-text ' + cssStyleStageText,
                cssStyleShape: cssStyleShape + ' ' + cssStyleStatusColor,
                cssStyleArrowTop: 'stage-arrow-top ' + cssStyleStatusColor,
                cssStyleArrowBottom: 'stage-arrow-bottom ' + cssStyleStatusColor
            };
        }
        this.initiativeStagesPath = dependentPicklistObject;
    }

    handleMouseOver(event) {
        const selectedStageId = event.currentTarget.dataset.stageid;
        let selectedStage = this.initiativeStagesPath.find(stage => stage.id === selectedStageId);

        if (selectedStage.complete == true) {
            let selectedStageIndex = this.initiativeStagesPath.findIndex(stageIndex => stageIndex.id === selectedStageId);
            this.previousIndex = selectedStageIndex;
            this.initiativeStagesPath[selectedStageIndex].showComplete = true;

            let backgroundElements = this.template.querySelectorAll('[data-stageid="' + selectedStageId + '"]');
            backgroundElements.forEach(element => {
                element.style.setProperty('--background-color-complete', 'rgba(25, 71, 113, 1)');
            });
        }

        if (selectedStage.complete == false) {
            let backgroundElements = this.template.querySelectorAll('[data-stageid="' + selectedStageId + '"]');
            backgroundElements.forEach(element => {
                element.style.setProperty('--background-color-incomplete', 'rgb(201, 201, 201)');
            });
        }

        if (selectedStage.current == true) {
            let backgroundElements = this.template.querySelectorAll('[data-stageid="' + selectedStageId + '"]');
            backgroundElements.forEach(element => {
                element.style.setProperty('--background-color-current', 'rgba(5, 25, 44, 1)');
            });
        }

    }

    handleMouseOut(event) {
        const selectedStageId = event.currentTarget.dataset.stageid;
        let selectedStageIndex = this.initiativeStagesPath.findIndex(stageIndex => stageIndex.id === selectedStageId);

        if (this.initiativeStagesPath[this.previousIndex].complete == true) {
            this.initiativeStagesPath[this.previousIndex].showComplete = false;
            let backgroundElements = this.template.querySelectorAll('[data-stageid="' + selectedStageId + '"]');
            backgroundElements.forEach(element => {
                element.style.setProperty('--background-color-complete', 'rgba(57, 152, 236, 1)');
            });
        }

        if (this.initiativeStagesPath[selectedStageIndex].complete == false) {
            let backgroundElements = this.template.querySelectorAll('[data-stageid="' + selectedStageId + '"]');
            backgroundElements.forEach(element => {
                element.style.setProperty('--background-color-incomplete', 'rgb(243, 243, 243)');
            });
        }

        if (this.initiativeStagesPath[selectedStageIndex].current == true) {
            let backgroundElements = this.template.querySelectorAll('[data-stageid="' + selectedStageId + '"]');
            backgroundElements.forEach(element => {
                element.style.setProperty('--background-color-current', 'rgb(14, 48, 79, 1)');
            });
        }
    }

    handleOnClick(event) {
        const selectedStageId = event.currentTarget.dataset.stageid;
        this.selectedInitiativeStage = this.initiativeStagesPath.find(stage => stage.id === selectedStageId);
    }

    updateStageValue() {
        this.updateInitiativeStageField();
    }

    displayToastSuccess() {
        LightningToast.show({
            label: "Initiative Stage changed successfully.",
            mode: "dismissible",
            variant: "success",
        }, this,);
    }

    handleCompleteButtonBehavior() {
        console.log('handleCompleteButtonBehavior');
    }

    get isPathComplete() {
        let completedStatus = false;
        let currentStage = this.benefitRecords.data ? getFieldValue(this.benefitRecords.data, INITIATIVE_STAGE_FIELD) : '';
        if (currentStage == 'Completed' || currentStage == null) {
            completedStatus = true;
        }
        return completedStatus;
    }

    get benefitSubtypeCurrentValue() {
        return this.benefitRecords.data ? getFieldValue(this.benefitRecords.data, BENEFIT_SUBTYPE_FIELD) : '';
    }

    get initiativeStageCurrentValue() {
        return this.benefitRecords.data ? getFieldValue(this.benefitRecords.data, INITIATIVE_STAGE_FIELD) : '';
    }
}