import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createBenefits from '@salesforce/apex/CsvFileUploaderController.createBenefits';
import { EnclosingTabId, IsConsoleNavigation, setTabLabel, setTabIcon } from 'lightning/platformWorkspaceApi';

export default class CsvFileUploader extends LightningElement {

    @wire(EnclosingTabId) enclosingTabId;
    @wire(IsConsoleNavigation) isConsoleNavigation;

    @track fileName = '';
    @track headers = [];
    @track rows = [];
    @track rowsPreview = [];
    @track previewLimit = 5;
    @track isLoading = false;
    @track lastResult = null;

    tableHeaders = [
        { id: 'colid1', label: 'Account' },
        { id: 'colid28', label: 'Benefit Type' },
        { id: 'colid2', label: 'Client SSN' },
        { id: 'colid27', label: 'Client PID' },
        { id: 'colid3', label: 'Client Last' },
        { id: 'colid4', label: 'Client First' },
        { id: 'colid5', label: 'Client DOB' },
        { id: 'colid6', label: 'Group' },
        { id: 'colid7', label: 'City' },
        { id: 'colid8', label: 'State' },
        { id: 'colid9', label: 'CU1' },
        { id: 'colid10', label: 'CU2' },
        { id: 'colid11', label: 'CU3' },
        { id: 'colid12', label: 'CU4' },
        { id: 'colid13', label: 'PBI SSN' },
        { id: 'colid14', label: 'PBI Last' },
        { id: 'colid15', label: 'PBI First' },
        { id: 'colid16', label: 'PBI DOB' },
        { id: 'colid17', label: 'PBI DOD' },
        { id: 'colid18', label: 'PBI City' },
        { id: 'colid19', label: 'PBI State' },
        { id: 'colid20', label: 'PBI Zip' },
        { id: 'colid21', label: 'Source' },
        { id: 'colid22', label: 'Url 1' },
        { id: 'colid23', label: 'Url 2' },
        { id: 'colid24', label: 'Url 3' },
        { id: 'colid25', label: 'Url 4' },
        { id: 'colid26', label: 'Url 5' },
    ];

    /*
    get createDisabled() {
        return !this.fileName || this.rows.length === 0;
    }

    get hasFailures() {
        return this.lastResult && this.lastResult.failed && this.lastResult.failed.length > 0;
    }

    get failureCount() {
        return this.lastResult && this.lastResult.failed ? this.lastResult.failed.length : 0;
    }
    */

    connectedCallback() {
        this.setTabInformation();
    }

    handleFileChange(evt) {
        const file = evt.target.files[0];
        if (!file) return;
        this.fileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            try {
                const parsed = this.parseCSV(reader.result);
                this.headers = Object.keys(parsed[0] || {});
                this.rows = parsed;
                //this.rowsPreview = parsed.slice(0, this.previewLimit);
                this.rowsPreview = parsed;
                this.lastResult = null;
            } catch (e) {
                this.showToast('CSV parse error: ' + e.message, 'error');
                this.clearParsed();
            }
        };
        reader.readAsText(file, 'UTF-8');
    }

    parseCSV(text) {
        const lines = text.split(/\r?\n/).filter(l => l.trim() !== '');
        if (lines.length < 2) return [];
        const headers = lines[0].split(',').map(h => h.trim());
        //return lines.slice(1).map((line, index) => {
        return lines.slice(1).map((line) => {
            const cols = line.split(',');
            const obj = {};
            headers.slice(0).forEach((h, i) => {
                obj[h] = cols[i] ? cols[i].trim() : null;
            });
            return obj;
        });
    }

    createRecords() {
        this.isLoading = true;
        createBenefits({ jsonRows: JSON.stringify(this.rows) })
            .then(res => {
                this.lastResult = res;
                this.isLoading = false;
                //this.showToast(`Created ${res.successCount} Benefit__c records.`, 'success');
                this.showToast(`The Benefit records were created successfully.`, 'success');
            })
            .catch(err => {
                this.isLoading = false;
                const msg = err?.body?.message || JSON.stringify(err);
                this.showToast('Error: ' + msg, 'error');
            });
    }

    setTabInformation() {
        if (!this.isConsoleNavigation) {
            return;
        } else {
            setTabLabel(this.enclosingTabId, 'CSV File Uploader').then(() => {
                console.log('Tab label updated successfully');
            }).catch((error) => {
                console.error('Error updating tab label:', error);
            });

            setTabIcon(this.enclosingTabId, 'utility:file', {
                iconAlt: 'Benefits'
            });
        }
    }

    clearAll() {
        this.fileName = '';
        this.clearParsed();
        this.lastResult = null;
        this.template.querySelectorAll('input[type="file"]').forEach(i => i.value = null);
    }

    clearParsed() {
        this.headers = [];
        this.rows = [];
        this.rowsPreview = [];
    }

    showToast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: variant === 'error' ? 'Error' : 'Info',
            message,
            variant
        }));
    }
}