import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getJourneyWithModules from '@salesforce/apex/JourneyModuleAssignmentController.getJourneyWithModules';
import createModuleAssignments from '@salesforce/apex/JourneyModuleAssignmentController.createModuleAssignments';

export default class JourneyModuleAssignment extends LightningElement {
    @api recordId;

    @track journeyName = '';
    @track modules = [];
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track searchTerm = '';
    @track sortField = 'name';
    @track sortDirection = 'asc';
    @track selectedRowIds = [];
    @track isSaving = false;
    @track currentPage = 1;

    pageSize = 10;
    _wiredDataResult;

    @wire(getJourneyWithModules, { journeyId: '$recordId' })
    wiredData(result) {
        this._wiredDataResult = result;
        const { data, error } = result;
        if (data) {
            this.journeyName = data.journeyName || '';
            this.modules = data.modules || [];
            this.hasError = false;
            this.isLoading = false;
        } else if (error) {
            this.errorMessage = error.body?.message || 'An unexpected error occurred.';
            this.hasError = true;
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.currentPage = 1;
    }

    handleSortColumn(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = 'asc';
        }
        this.currentPage = 1;
    }

    handleCheckboxChange(event) {
        const id = event.target.dataset.id;
        if (event.target.checked) {
            if (!this.selectedRowIds.includes(id)) {
                this.selectedRowIds = [...this.selectedRowIds, id];
            }
        } else {
            this.selectedRowIds = this.selectedRowIds.filter(rid => rid !== id);
        }
    }

    handlePrevPage() {
        if (this.currentPage > 1) this.currentPage -= 1;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) this.currentPage += 1;
    }

    handleCreateAssignments() {
        if (!this.selectedRowIds.length) return;
        this.isSaving = true;
        createModuleAssignments({ journeyId: this.recordId, moduleIds: this.selectedRowIds })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: `${this.selectedRowIds.length} module assignment(s) created successfully.`,
                    variant: 'success'
                }));
                this.selectedRowIds = [];
                this.currentPage = 1;
                refreshApex(this._wiredDataResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: err.body?.message || 'Failed to create assignments.',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    get cardTitle() {
        return this.journeyName ? `Module Assignment ${this.journeyName}` : 'Module Assignment';
    }

    get displayedModules() {
        let list = [...this.modules];
        if (this.searchTerm) {
            list = list.filter(m =>
                (m.name || '').toLowerCase().includes(this.searchTerm) ||
                (m.moduleName || '').toLowerCase().includes(this.searchTerm)
            );
        }
        const multiplier = this.sortDirection === 'asc' ? 1 : -1;
        list.sort((a, b) => {
            const valA = (a[this.sortField] || '').toString().toLowerCase();
            const valB = (b[this.sortField] || '').toString().toLowerCase();
            if (valA < valB) return -1 * multiplier;
            if (valA > valB) return 1 * multiplier;
            return 0;
        });
        return list;
    }

    get paginatedModules() {
        const start = (this.currentPage - 1) * this.pageSize;
        const selectedSet = new Set(this.selectedRowIds);
        return this.displayedModules.slice(start, start + this.pageSize).map(m => ({
            ...m,
            isSelected: selectedSet.has(m.id),
            rowClass: m.isAssigned ? 'assigned-row' : ''
        }));
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.displayedModules.length / this.pageSize));
    }

    get pageInfo() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get isPrevDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    get hasModules() {
        return this.displayedModules.length > 0;
    }

    get selectedCount() {
        return this.selectedRowIds.length;
    }

    get hasSelection() {
        return this.selectedRowIds.length > 0;
    }

    get nameColClass() {
        return this._colClass('name');
    }

    get moduleNameColClass() {
        return this._colClass('moduleName');
    }

    get nameSortIcon() {
        return this._sortIcon('name');
    }

    get moduleNameSortIcon() {
        return this._sortIcon('moduleName');
    }

    _colClass(field) {
        let cls = 'slds-is-sortable';
        if (this.sortField === field) {
            cls += this.sortDirection === 'asc' ? ' slds-is-sorted slds-is-sorted_asc' : ' slds-is-sorted slds-is-sorted_desc';
        }
        return cls;
    }

    _sortIcon(field) {
        if (this.sortField !== field) return 'utility:arrowdown';
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }
}