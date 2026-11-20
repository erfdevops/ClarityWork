import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasSmartGoalBulkUploadAccess from '@salesforce/customPermission/Smart_Goal_Bulk_Upload_Access';
import getFiscalYears from '@salesforce/apex/SmartGoalBulkUploadController.getFiscalYears';
import previewUpload  from '@salesforce/apex/SmartGoalBulkUploadController.previewUpload';
import executeUpload  from '@salesforce/apex/SmartGoalBulkUploadController.executeUpload';

const SOURCE_FY_DEFAULT = 'October 2025 - September 2026';
const TARGET_FY_DEFAULT = 'October 2026 - September 2027';

export default class SmartGoalBulkUpload extends LightningElement {

    get isAuthorized() { return hasSmartGoalBulkUploadAccess; }

    @track sourceFY   = SOURCE_FY_DEFAULT;
    @track targetFY   = TARGET_FY_DEFAULT;
    @track fyOptions  = [];
    @track fileName   = '';
    @track isLoading  = false;
    @track preview    = null;
    @track executeResult = null;

    _parsedRows = [];

    // ── Wire ──────────────────────────────────────────────────────────────────

    @wire(getFiscalYears)
    wiredFYs({ data, error }) {
        if (data) {
            this.fyOptions = data.map(v => ({ label: v, value: v }));
        } else if (error) {
            this.showToast('Could not load fiscal years: ' + (error.body?.message || JSON.stringify(error)), 'error');
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────────

    get rowCount() { return this._parsedRows.length; }

    get employeeCount() {
        const keys = new Set(this._parsedRows.map(r =>
            ((r.Employee_Email || r.Employee_Name || '').toLowerCase())
        ));
        keys.delete('');
        return keys.size;
    }

    get fyWarning() {
        if (this.sourceFY && this.targetFY && this.sourceFY === this.targetFY) {
            return 'Source and target fiscal years are the same. Please select different years.';
        }
        return null;
    }

    get previewDisabled() {
        return this.isLoading || !this.fileName || this._parsedRows.length === 0 || !!this.fyWarning;
    }

    get executeDisabled() {
        return this.isLoading || !this.preview || !!this.fyWarning;
    }

    get showPreview()      { return !!this.preview; }
    get showSuccessState() { return !!(this.executeResult && this.executeResult.success); }
    get showErrorResult()  { return !!(this.executeResult && !this.executeResult.success); }
    get hasWarnings()      { return this.preview && this.preview.warningCount > 0; }

    get totalGoalCount() {
        if (!this.preview) return 0;
        return (this.preview.newGoalCount || 0) + (this.preview.copiedGoalCount || 0);
    }

    // Decorate employee rows with computed flags for template conditionals
    get previewWithFlags() {
        if (!this.preview) return null;
        return {
            ...this.preview,
            employees: (this.preview.employees || []).map(e => ({
                ...e,
                isNew:  e.action === 'new',
                isCopy: e.action === 'copy',
                isWarn: e.action === 'warn',
                rowClass: e.action === 'warn' ? 'slds-theme_error' : ''
            }))
        };
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleSourceFYChange(evt) {
        this.sourceFY = evt.detail.value;
        this.preview  = null;
        this.executeResult = null;
    }

    handleTargetFYChange(evt) {
        this.targetFY = evt.detail.value;
        this.preview  = null;
        this.executeResult = null;
    }

    handleFileChange(evt) {
        const file = evt.target.files[0];
        if (!file) return;
        this.fileName = file.name;
        this.preview  = null;
        this.executeResult = null;
        const reader = new FileReader();
        reader.onload = () => {
            try {
                this._parsedRows = this.parseCSV(reader.result);
                if (this._parsedRows.length === 0) {
                    this.showToast('No data rows found in CSV.', 'warning');
                }
            } catch (e) {
                this.showToast('CSV parse error: ' + e.message, 'error');
                this._parsedRows = [];
                this.fileName = '';
            }
        };
        reader.readAsText(file, 'UTF-8');
    }

    handlePreview() {
        this.isLoading = true;
        this.executeResult = null;
        previewUpload({
            jsonRows: JSON.stringify(this._parsedRows),
            targetFY: this.targetFY,
            sourceFY: this.sourceFY
        })
        .then(result => {
            // Attach computed flags for template
            result.employees = (result.employees || []).map(e => ({
                ...e,
                isNew:    e.action === 'new',
                isCopy:   e.action === 'copy',
                isWarn:   e.action === 'warn',
                rowClass: e.action === 'warn' ? 'slds-theme_error' : ''
            }));
            this.preview = result;
            this.isLoading = false;
        })
        .catch(err => {
            this.isLoading = false;
            this.showToast('Preview error: ' + (err?.body?.message || JSON.stringify(err)), 'error');
        });
    }

    handleExecute() {
        // eslint-disable-next-line no-alert
        if (!confirm(
            'This will create Annual Plans and SMART Goals in ' + this.targetFY + '.\n\n' +
            'Are you sure you want to proceed?'
        )) return;

        this.isLoading = true;
        this.executeResult = null;
        executeUpload({
            jsonRows: JSON.stringify(this._parsedRows),
            targetFY: this.targetFY,
            sourceFY: this.sourceFY
        })
        .then(result => {
            this.executeResult = result;
            this.isLoading = false;
            if (result.success) {
                this.showToast(
                    `Done. ${result.plansCreated} plan(s) created, ` +
                    `${result.goalsCreated} new goal(s), ` +
                    `${result.stagesCreated} stage(s), ` +
                    `${result.goalsCopied} goal(s) copied.`,
                    'success'
                );
                // Reset file + preview so the tool can't be re-run accidentally
                this.clearFile();
                this.preview = null;
            } else {
                this.showToast('Execution failed. See error details below.', 'error');
            }
        })
        .catch(err => {
            this.isLoading = false;
            this.showToast('Execute error: ' + (err?.body?.message || JSON.stringify(err)), 'error');
        });
    }

    handleClear() {
        this.clearFile();
        this.preview = null;
        this.executeResult = null;
    }

    handleStartOver() {
        this.handleClear();
    }

    // ── CSV parser (RFC 4180, handles quoted fields with commas) ─────────────

    parseCSV(text) {
        // Normalize all line ending variants (\r\n, \r, \n) to \n
        const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
        if (lines.length < 2) return [];

        // Find the real header row — scan up to 25 lines to skip filter/blank preamble.
        // For the report format, the header row uniquely contains "ownership" (Initiative: Ownership ↑).
        // Avoid matching preamble rows like "Show: All smart goals" which also contain "smart goal".
        let headerIdx = 0;
        for (let i = 0; i < Math.min(lines.length, 25); i++) {
            const line = lines[i].trim();
            if (!line) continue;
            const cols = this.splitCSVLine(line).map(c => c.trim().toLowerCase());
            if (cols.some(c => c === 'employee_email') ||
                cols.some(c => c.includes('ownership')) ||
                cols.filter(c => c.includes('initiative')).length >= 3) {
                headerIdx = i;
                break;
            }
        }

        const rawHeaders = this.splitCSVLine(lines[headerIdx]).map(h => h.trim());

        // Detect report-export format (has "Ownership" / multiple "Initiative" headers, no Employee_Email)
        const lh = rawHeaders.map(h => h.toLowerCase());
        const isReportFormat = (lh.some(h => h.includes('ownership')) || lh.filter(h => h.includes('initiative')).length >= 3)
            && !lh.some(h => h === 'employee_email');

        if (isReportFormat) {
            return this.parseReportFormat(lines, headerIdx, rawHeaders);
        }

        // Original template format
        const results = [];
        for (let i = headerIdx + 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            const cols = this.splitCSVLine(line);
            const obj = {};
            rawHeaders.forEach((h, idx) => {
                obj[h] = cols[idx] !== undefined ? cols[idx].trim() : '';
            });
            results.push(obj);
        }
        return results;
    }

    // Parses the Salesforce report-export format into normalized goal rows
    parseReportFormat(lines, headerIdx, headers) {
        const lc = headers.map(h => h.toLowerCase());
        // Employee name: prefer column with "ownership"; fall back to column 0
        const ownerCol    = lc.findIndex(h => h.includes('ownership')) !== -1
            ? lc.findIndex(h => h.includes('ownership')) : 0;
        const goalNameCol = lc.findIndex(h => h.includes('initiative') && h.includes('name'));
        // Pick the shortest column that contains 'smart goal' — avoids the longer ID column
        const sgIdxs    = lc.reduce((acc, h, i) => { if (h.includes('smart goal')) acc.push(i); return acc; }, []);
        const goalTextCol = sgIdxs.length > 0
            ? sgIdxs.reduce((best, i) => lc[i].length < lc[best].length ? i : best, sgIdxs[0])
            : -1;

        if (goalTextCol < 0) {
            this.showToast(
                'Could not find a "SMART Goal" column. Headers detected: ' +
                headers.filter(h => h).join(', '),
                'error'
            );
            return [];
        }

        // Find "Initiative Stage N" columns (1–12) — these hold per-month stage names
        const stageCols = [];
        for (let n = 1; n <= 12; n++) {
            stageCols.push(lc.findIndex(h => h === `initiative stage ${n}`));
        }

        const results = [];
        let lastEmployeeName = '';

        for (let i = headerIdx + 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            const cols = this.splitCSVLine(line);

            // Skip subtotal / total rows — they have no goal text
            const goalText = goalTextCol >= 0 ? (cols[goalTextCol] || '').trim() : '';
            if (!goalText) continue;

            // Carry employee name forward from the first row of each group
            const nameCell = ownerCol >= 0 ? (cols[ownerCol] || '').trim() : '';
            if (nameCell) lastEmployeeName = nameCell;
            if (!lastEmployeeName) continue;

            const goalName = goalNameCol >= 0 ? (cols[goalNameCol] || '').trim() : '';

            // Read stage name columns; treat placeholder text as blank
            const isPlaceholder = v => !v || v.startsWith('[');
            const row = {
                Employee_Email:    '',
                Employee_Name:     lastEmployeeName,
                Goal_Name:         goalName,
                Goal_Description:  goalText,
                Metric:            '',
                Weight_Percentage: '',
                Goal_Start_Date:   '',
                Goal_End_Date:     '',
                Stage_Name:        '',
                Stage_Description: '',
                Stage_Step_Number: '',
                Stage_Start_Date:  '',
                Stage_End_Date:    ''
            };
            stageCols.forEach((colIdx, n) => {
                const raw = colIdx >= 0 ? (cols[colIdx] || '').trim() : '';
                row[`Stage_${n + 1}`] = isPlaceholder(raw) ? '' : raw;
            });
            results.push(row);
        }
        return results;
    }

    splitCSVLine(line) {
        const result = [];
        let inQuotes = false;
        let current  = '';
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') {
                    current += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch === ',' && !inQuotes) {
                result.push(current);
                current = '';
            } else {
                current += ch;
            }
        }
        result.push(current);
        return result;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    clearFile() {
        this.fileName = '';
        this._parsedRows = [];
        const input = this.template.querySelector('input[type="file"]');
        if (input) input.value = null;
    }

    showToast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title:   variant === 'error' ? 'Error' : variant === 'warning' ? 'Warning' : 'Success',
            message,
            variant: variant === 'warning' ? 'warning' : variant
        }));
    }
}
