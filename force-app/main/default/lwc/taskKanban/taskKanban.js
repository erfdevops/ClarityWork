import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import SHEETJS_URL from '@salesforce/resourceUrl/SheetJS';
import getUserTasks     from '@salesforce/apex/TaskKanbanController.getUserTasks';
import getUserProjects  from '@salesforce/apex/TaskKanbanController.getUserProjects';
import getSmartGoals    from '@salesforce/apex/TaskKanbanController.getSmartGoals';
import getExportColumns from '@salesforce/apex/TaskKanbanController.getExportColumns';
import getActiveUsers   from '@salesforce/apex/TaskKanbanController.getActiveUsers';
import getTaskComments  from '@salesforce/apex/TaskKanbanController.getTaskComments';
import addComment       from '@salesforce/apex/TaskKanbanController.addComment';
import deleteComment    from '@salesforce/apex/TaskKanbanController.deleteComment';
import updateTaskStatus          from '@salesforce/apex/TaskKanbanController.updateTaskStatus';
import createTask                from '@salesforce/apex/TaskKanbanController.createTask';
import updateTask                from '@salesforce/apex/TaskKanbanController.updateTask';
import deleteTask                from '@salesforce/apex/TaskKanbanController.deleteTask';
import getTaskSyncedFiles        from '@salesforce/apex/TaskKanbanController.getTaskSyncedFiles';
import syncTaskFilesToSharePoint from '@salesforce/apex/TaskKanbanController.syncTaskFilesToSharePoint';
import getTaskSmartGoals         from '@salesforce/apex/TaskKanbanController.getTaskSmartGoals';
import triggerRecurringSpawn      from '@salesforce/apex/TaskKanbanController.triggerRecurringSpawn';
import getRecurringTemplates      from '@salesforce/apex/TaskKanbanController.getRecurringTemplates';
import saveRecurringTemplate      from '@salesforce/apex/TaskKanbanController.saveRecurringTemplate';
import toggleRecurringTemplate    from '@salesforce/apex/TaskKanbanController.toggleRecurringTemplate';
import deleteRecurringTemplate    from '@salesforce/apex/TaskKanbanController.deleteRecurringTemplate';
import getTemplateSmartGoals      from '@salesforce/apex/TaskKanbanController.getTemplateSmartGoals';
import getRelatedTasks            from '@salesforce/apex/TaskKanbanController.getRelatedTasks';
import saveTaskRelations          from '@salesforce/apex/TaskKanbanController.saveTaskRelations';
import getTaskProjects            from '@salesforce/apex/TaskKanbanController.getTaskProjects';
import saveTaskProjects           from '@salesforce/apex/TaskKanbanController.saveTaskProjects';
import getTemplateProjects        from '@salesforce/apex/TaskKanbanController.getTemplateProjects';
import saveTemplateProjects       from '@salesforce/apex/TaskKanbanController.saveTemplateProjects';
import saveMentions               from '@salesforce/apex/TaskKanbanController.saveMentions';
import getInitiativeStages        from '@salesforce/apex/TaskKanbanController.getInitiativeStages';
import attachCsvToInitiativeStage from '@salesforce/apex/TaskKanbanController.attachCsvToInitiativeStage';
import bulkUpdateStatus           from '@salesforce/apex/TaskKanbanController.bulkUpdateStatus';
import bulkAssignToMonth          from '@salesforce/apex/TaskKanbanController.bulkAssignToMonth';
import searchTags                 from '@salesforce/apex/TaskKanbanController.searchTags';
import ensureTag                  from '@salesforce/apex/TaskKanbanController.ensureTag';
import getTaskTags                from '@salesforce/apex/TaskKanbanController.getTaskTags';
import saveTaskTags               from '@salesforce/apex/TaskKanbanController.saveTaskTags';
import getTemplateTags            from '@salesforce/apex/TaskKanbanController.getTemplateTags';
import saveTemplateTags           from '@salesforce/apex/TaskKanbanController.saveTemplateTags';

const MONTH_NAMES = ['January','February','March','April','May','June',
                     'July','August','September','October','November','December'];

// Returns a Date object set to the 1st of next month from today
function _nextMonth() {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth() + 1, 1);
}

export default class TaskKanban extends LightningElement {

    @track selectedProjectId   = '';
    @track selectedSmartGoalId = '';
    @track selectedMonth;
    @track showMonthPicker     = false;
    @track pickerYear          = String(new Date().getFullYear());
    @track pickerMonth         = String(new Date().getMonth() + 1);
    @track searchKeyword       = '';
    // Assign to Month — new task form
    @track newAssignOpen       = false;
    @track newAssignYear       = String(_nextMonth().getFullYear());
    @track newAssignMonth      = String(_nextMonth().getMonth() + 1);
    // Assign to Month — edit task form
    @track editAssignOpen      = false;
    @track editAssignYear      = '';
    @track editAssignMonth     = '';
    // Assign to Month — bulk action
    @track bulkAssignYear      = String(_nextMonth().getFullYear());
    @track bulkAssignMonth     = String(_nextMonth().getMonth() + 1);
    @track showBulkAssignPicker = false;
    @track bulkAssignLoading   = false;
    @track selectedPriority    = '';
    @track columnSorts = {
        'Queue':       { field: 'CreatedDate', dir: 'desc' },
        'In Progress': { field: 'CreatedDate', dir: 'desc' },
        'Complete':    { field: 'CreatedDate', dir: 'desc' }
    };
    @track showNewTaskModal    = false;
    @track showEditModal       = false;
    @track showDeleteConfirm   = false;
    @track newTask  = { Subject: '', projectId: '', Kanban_Status__c: 'Queue', Priority: 'Normal', ActivityDate: '', Description: '', timeSpent: null, assignedToId: '' };
    @track showRecurringModal   = false;
    @track recurringTemplates   = [];
    @track recurringTemplateForm = { Subject__c: '', projectId: '', Priority__c: 'Normal', Description__c: '', assignedToId: '', assignedLabel: '', Is_Active__c: true, frequency: 'Monthly', spawnDay: null };
    @track editingTemplateId    = null;
    @track showTemplateForm     = false;
    @track templateSmartGoalIds = [];
    @track templateSmartGoalSearch = '';
    @track showTemplateSmartGoalDropdown = false;
    @track editRelatedTaskIds = [];
    @track editRelatedTaskSearch = '';
    @track showEditRelatedDropdown = false;
    @track newRelatedTaskIds = [];
    @track newRelatedTaskSearch = '';
    @track showNewRelatedDropdown = false;
    @track editProjectIds = [];
    @track editProjectSearch = '';
    @track showEditProjectDropdown = false;
    @track newProjectIds = [];
    @track newProjectSearch = '';
    @track showNewProjectDropdown = false;
    @track templateProjectIds = [];
    @track templateProjectSearch = '';
    @track showTemplateProjectDropdown = false;
    @track editTaskTagChips = [];
    @track editTaskTagSearch = '';
    @track showEditTaskTagDropdown = false;
    @track editTaskTagOptions = [];
    @track newTaskTagChips = [];
    @track newTaskTagSearch = '';
    @track showNewTaskTagDropdown = false;
    @track newTaskTagOptions = [];
    @track templateTagChips = [];
    @track templateTagSearch = '';
    @track showTemplateTagDropdown = false;
    @track templateTagOptions = [];
    @track editTask = {};
    @track _editTaskId = null;
    @track newCommentText = '';
    @track showMentionDropdown = false;
    @track showEditDescDropdown = false;
    @track showNewDescDropdown = false;
    @track showTmplDescDropdown = false;
    @track isSyncing = false;
    _mentionQuery = '';
    _mentionAtStart = 0;
    _mentionedUserIds = [];
    _editDescMentionQuery = '';
    _editDescMentionAtStart = 0;
    _editDescMentionedIds = [];
    _newDescMentionQuery = '';
    _newDescMentionAtStart = 0;
    _newDescMentionedIds = [];
    _tmplDescMentionQuery = '';
    _tmplDescMentionAtStart = 0;
    _tmplDescMentionedIds = [];
    _prevShowEditModal = false;
    _prevShowNewTaskModal = false;
    _prevShowTemplateForm = false;
    @track _newTaskSavedId = null;
    @track newTaskHasAttachments = false;
    @track editSmartGoalIds = [];
    @track editSmartGoalSearch = '';
    @track showEditSmartGoalDropdown = false;
    @track newSmartGoalIds = [];
    @track newSmartGoalSearch = '';
    @track showNewSmartGoalDropdown = false;
    @track editAssignedLabel = '';
    @track newAssignedLabel = '';
    @track showEditAssignedDropdown = false;
    @track showNewAssignedDropdown = false;
    _pendingDeleteId = null;
    _dragTaskId = null;
    _wiredTasksResult;
    _wiredCommentsResult;
    _wiredSyncedFilesResult;
    _exportColumns = [];
    _xlsxReady = false;
    @track showExportModal = false;
    @track exportFormat = 'xlsx';
    @track exportFieldSelection = [];
    @track showPrefsModal = false;
    @track showReportModal = false;
    @track selectMode = false;
    @track selectedTaskIds = [];
    @track bulkLoading = false;
    @track showSubmitModal = false;
    @track submitStageOptions = [];
    @track selectedSubmitStageId = '';
    @track submitLoading = false;
    @track submitFormat = 'xlsx';
    _submitStagesRaw = [];

    // ─── Wire: Tasks ──────────────────────────────────────────────────────────
    @wire(getUserTasks, { projectId: '$selectedProjectId' })
    wiredTasks(result) {
        this._wiredTasksResult = result;
    }

    // ─── Wire: Projects ───────────────────────────────────────────────────────
    @wire(getUserProjects)
    projects;

    // ─── Wire: Smart Goals ────────────────────────────────────────────────────
    @wire(getSmartGoals)
    smartGoals;

    // ─── Wire: Active Users ───────────────────────────────────────────────────
    @wire(getActiveUsers)
    activeUsers;

    // ─── Wire: Task Comments ──────────────────────────────────────────────────
    @wire(getTaskComments, { taskId: '$_editTaskId' })
    wiredComments(result) {
        this._wiredCommentsResult = result;
    }

    // ─── SharePoint Synced Files (imperative — not cacheable) ─────────────────
    loadSyncedFiles() {
        if (!this._editTaskId) { this._wiredSyncedFilesResult = []; return; }
        getTaskSyncedFiles({ taskId: this._editTaskId })
            .then(data => { this._wiredSyncedFilesResult = data || []; })
            .catch(() => { this._wiredSyncedFilesResult = []; });
    }

    // ─── Smart Goal junction records (imperative) ─────────────────────────────
    loadTaskSmartGoals() {
        if (!this._editTaskId) { this.editSmartGoalIds = []; return; }
        getTaskSmartGoals({ taskId: this._editTaskId })
            .then(data => { this.editSmartGoalIds = (data || []).map(r => r.Smart_Goal__c); })
            .catch(() => { this.editSmartGoalIds = []; });
    }

    loadRelatedTasks() {
        if (!this._editTaskId) { this.editRelatedTaskIds = []; return; }
        getRelatedTasks({ taskId: this._editTaskId })
            .then(data => { this.editRelatedTaskIds = (data || []).map(t => t.Id); })
            .catch(() => { this.editRelatedTaskIds = []; });
    }

    loadTemplateSmartGoals() {
        if (!this.editingTemplateId) { this.templateSmartGoalIds = []; return; }
        getTemplateSmartGoals({ templateId: this.editingTemplateId })
            .then(data => { this.templateSmartGoalIds = (data || []).map(r => r.Smart_Goal__c); })
            .catch(() => { this.templateSmartGoalIds = []; });
    }

    loadTaskProjects() {
        if (!this._editTaskId) { this.editProjectIds = []; return; }
        getTaskProjects({ taskId: this._editTaskId })
            .then(data => { this.editProjectIds = (data || []).map(p => p.Id); })
            .catch(() => { this.editProjectIds = []; });
    }

    loadTemplateProjects() {
        if (!this.editingTemplateId) { this.templateProjectIds = []; return; }
        getTemplateProjects({ templateId: this.editingTemplateId })
            .then(data => { this.templateProjectIds = (data || []).map(p => p.Id); })
            .catch(() => { this.templateProjectIds = []; });
    }

    loadTaskTags() {
        if (!this._editTaskId) { this.editTaskTagChips = []; return; }
        getTaskTags({ taskId: this._editTaskId })
            .then(data => { this.editTaskTagChips = (data || []).map(t => ({ id: t.Id, label: t.Name })); })
            .catch(() => { this.editTaskTagChips = []; });
    }

    loadTemplateTags() {
        if (!this.editingTemplateId) { this.templateTagChips = []; return; }
        getTemplateTags({ templateId: this.editingTemplateId })
            .then(data => { this.templateTagChips = (data || []).map(t => ({ id: t.Id, label: t.Name })); })
            .catch(() => { this.templateTagChips = []; });
    }

    // ─── Wire: Export columns ─────────────────────────────────────────────────
    @wire(getExportColumns)
    wiredColumns({ data }) {
        if (data) this._exportColumns = data;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        const now = new Date();
        this.selectedMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
        this._loadPrefs();
        loadScript(this, SHEETJS_URL)
            .then(() => { this._xlsxReady = true; })
            .catch(() => { this._xlsxReady = false; });
    }

    _loadPrefs() {
        try {
            const raw = localStorage.getItem('clarityWork_exportPrefs');
            if (raw) {
                const saved = JSON.parse(raw);
                if (Array.isArray(saved.fieldSelection) && saved.fieldSelection.length) {
                    // Merge: preserve saved enabled/disabled state; new columns appear as disabled
                    const savedMap = new Map(saved.fieldSelection.map(f => [f.key, f]));
                    this.exportFieldSelection = this._defaultExportColumns().map(c => {
                        if (savedMap.has(c.Field_API_Name__c)) return savedMap.get(c.Field_API_Name__c);
                        return { key: c.Field_API_Name__c, label: c.Column_Header__c, enabled: false };
                    });
                    return;
                }
            }
        } catch(e) { /* ignore parse errors */ }
        this._initFieldSelection();
    }

    _savePrefs() {
        try {
            localStorage.setItem('clarityWork_exportPrefs', JSON.stringify({
                fieldSelection: this.exportFieldSelection
            }));
        } catch(e) { /* ignore quota errors */ }
    }

    handleOpenPrefs() {
        this._initFieldSelection();
        this.showPrefsModal = true;
    }

    handleClosePrefs() {
        this.showPrefsModal = false;
    }

    handleResetFieldSelection() {
        this.exportFieldSelection = [];
        this._initFieldSelection();
        this._savePrefs();
    }

    renderedCallback() {
        if (this.showEditModal && !this._prevShowEditModal) {
            const ta = this.template.querySelector('.edit-desc-textarea');
            if (ta) ta.value = this.editTask.Description || '';
        }
        this._prevShowEditModal = this.showEditModal;

        if (this.showNewTaskModal && !this._prevShowNewTaskModal) {
            const ta = this.template.querySelector('.new-desc-textarea');
            if (ta) ta.value = this.newTask.Description || '';
        }
        this._prevShowNewTaskModal = this.showNewTaskModal;

        if (this.showTemplateForm && !this._prevShowTemplateForm) {
            const ta = this.template.querySelector('.tmpl-desc-textarea');
            if (ta) ta.value = this.recurringTemplateForm.Description__c || '';
        }
        this._prevShowTemplateForm = this.showTemplateForm;
    }

    get exportFormatOptions() {
        return [
            { label: 'CSV', value: 'csv' },
            { label: 'Excel (.xlsx)', value: 'xlsx' }
        ];
    }

    get submitFormatOptions() {
        return [
            { label: 'CSV', value: 'csv' },
            { label: 'Excel (.xlsx)', value: 'xlsx' }
        ];
    }

    // ─── Derived task lists ───────────────────────────────────────────────────
    get allTasks() {
        let tasks = (this._wiredTasksResult && this._wiredTasksResult.data) || [];
        const [year, month] = (this.selectedMonth || '').split('-').map(Number);
        if (year && month) {
            tasks = tasks.filter(t => {
                const inMonth = rawDate => {
                    if (!rawDate) return false;
                    const d = new Date(rawDate + 'T00:00:00');
                    return d.getFullYear() === year && d.getMonth() + 1 === month;
                };
                const effectiveDate = t.Assign_To_Month__c
                    ? t.Assign_To_Month__c
                    : (t.CreatedDate ? t.CreatedDate.slice(0, 10) : null);
                return inMonth(effectiveDate);
            });
        }
        if (this.selectedSmartGoalId) {
            tasks = tasks.filter(t => t.Smart_Goal__c === this.selectedSmartGoalId);
        }
        if (this.selectedPriority) {
            tasks = tasks.filter(t => t.Priority === this.selectedPriority);
        }
        if (this.searchKeyword) {
            const kw = this.searchKeyword.toLowerCase();
            tasks = tasks.filter(t =>
                (t.Subject || '').toLowerCase().includes(kw) ||
                (t.Description || '').toLowerCase().includes(kw) ||
                (t.Task_Number__c || '').toLowerCase().includes(kw) ||
                (t.Project__r && (t.Project__r.Name || '').toLowerCase().includes(kw))
            );
        }
        return tasks.map(t => ({
            ...t,
            formattedCreatedDate: t.CreatedDate
                ? new Date(t.CreatedDate).toLocaleString('en-US', {
                    month: 'short', day: 'numeric', year: 'numeric',
                    hour: 'numeric', minute: '2-digit'
                  })
                : '',
            priorityHigh: t.Priority === 'High',
            priorityLow:  t.Priority === 'Low',
            isSelected:   this.selectedTaskIds.includes(t.Id),
            cardClass:    'kanban-card' + (this.selectedTaskIds.includes(t.Id) ? ' kanban-card_selected' : '')
        }));
    }

    get queueTasks()      { return this.sortTasks(this.allTasks.filter(t => t.Kanban_Status__c === 'Queue' || !t.Kanban_Status__c), this.columnSorts['Queue']); }
    get inProgressTasks() { return this.sortTasks(this.allTasks.filter(t => t.Kanban_Status__c === 'In Progress'), this.columnSorts['In Progress']); }
    get completeTasks()   { return this.sortTasks(this.allTasks.filter(t => t.Kanban_Status__c === 'Complete'), this.columnSorts['Complete']); }

    sortTasks(tasks, colSort) {
        const { field, dir } = colSort;
        const d = dir === 'asc' ? 1 : -1;
        return [...tasks].sort((a, b) => {
            let aVal, bVal;
            if (field === 'Subject') {
                aVal = (a.Subject || '').toLowerCase();
                bVal = (b.Subject || '').toLowerCase();
            } else if (field === 'Task_Number__c') {
                aVal = a.Task_Number__c || '';
                bVal = b.Task_Number__c || '';
            } else {
                aVal = a.CreatedDate || '';
                bVal = b.CreatedDate || '';
            }
            return aVal < bVal ? -d : aVal > bVal ? d : 0;
        });
    }

    buildSortOptions(col) {
        const { field, dir } = this.columnSorts[col];
        const arrow = dir === 'asc' ? ' ↑' : ' ↓';
        return [
            { label: 'Name',    value: 'Subject' },
            { label: 'Task ID', value: 'Task_Number__c' },
            { label: 'Date',    value: 'CreatedDate' }
        ].map(o => ({
            col,
            value: o.value,
            label: o.value === field ? o.label + arrow : o.label,
            cls:   'sort-chip' + (o.value === field ? ' sort-chip_active' : '')
        }));
    }

    get queueSortOptions()      { return this.buildSortOptions('Queue'); }
    get inProgressSortOptions() { return this.buildSortOptions('In Progress'); }
    get completeSortOptions()   { return this.buildSortOptions('Complete'); }

    get queueCount()      { return String(this.queueTasks.length); }
    get inProgressCount() { return String(this.inProgressTasks.length); }
    get completeCount()   { return String(this.completeTasks.length); }

    // ─── Options ──────────────────────────────────────────────────────────────
    get projectOptions() {
        const opts = [{ label: 'All Projects', value: '' }];
        if (this.projects.data) {
            this.projects.data.forEach(p => opts.push({ label: p.Name, value: p.Id }));
        }
        return opts;
    }

    get smartGoalOptions() {
        const opts = [{ label: 'None', value: '' }];
        if (this.smartGoals && this.smartGoals.data) {
            this.smartGoals.data.forEach(g => opts.push({ label: g.Initiative_Name__c || g.Name, value: g.Id }));
        }
        return opts;
    }

    get smartGoalFilterOptions() {
        const opts = [{ label: 'All Smart Goals', value: '' }];
        if (this.smartGoals && this.smartGoals.data) {
            this.smartGoals.data.forEach(g => opts.push({ label: g.Initiative_Name__c || g.Name, value: g.Id }));
        }
        return opts;
    }

    get monthOptions() {
        const opts = [];
        const now = new Date();
        for (let i = -2; i <= 3; i++) {
            const d = new Date(now.getFullYear(), now.getMonth() + i, 1);
            const val = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
            opts.push({ label: `${MONTH_NAMES[d.getMonth()]} ${d.getFullYear()}`, value: val });
        }
        // If user has selected a historical month outside the rolling window, show it at the top
        const inWindow = opts.some(o => o.value === this.selectedMonth);
        if (this.selectedMonth && !inWindow) {
            const [yr, mo] = this.selectedMonth.split('-').map(Number);
            opts.unshift({ label: `${MONTH_NAMES[mo - 1]} ${yr}`, value: this.selectedMonth });
        }
        opts.push({ label: '— Other month…', value: '__picker__' });
        return opts;
    }

    get statusOptions() {
        return [
            { label: 'Queue',       value: 'Queue' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Complete',    value: 'Complete' }
        ];
    }

    get priorityOptions() {
        return [
            { label: 'High',   value: 'High' },
            { label: 'Normal', value: 'Normal' },
            { label: 'Low',    value: 'Low' }
        ];
    }

    get priorityFilterOptions() {
        return [
            { label: 'High',   value: 'High' },
            { label: 'Normal', value: 'Normal' },
            { label: 'Low',    value: 'Low' }
        ];
    }

    get frequencyOptions() {
        return [
            { label: 'Weekly',        value: 'Weekly' },
            { label: 'Every 2 Weeks', value: 'Bi-Weekly' },
            { label: 'Monthly',       value: 'Monthly' }
        ];
    }

    get isWeeklyOrBiWeekly() {
        const f = this.recurringTemplateForm.frequency;
        return f === 'Weekly' || f === 'Bi-Weekly';
    }

    get isMonthly() {
        return this.recurringTemplateForm.frequency === 'Monthly';
    }

    get spawnDayOfWeekOptions() {
        return [
            { label: 'Sunday',           value: '0' },
            { label: 'Monday (default)', value: '1' },
            { label: 'Tuesday',          value: '2' },
            { label: 'Wednesday',        value: '3' },
            { label: 'Thursday',         value: '4' },
            { label: 'Friday',           value: '5' },
            { label: 'Saturday',         value: '6' }
        ];
    }

    get spawnDayOfMonthOptions() {
        const result = [];
        for (let d = 1; d <= 31; d++) {
            let suffix;
            if (d >= 11 && d <= 13)   suffix = 'th';
            else if (d % 10 === 1)    suffix = 'st';
            else if (d % 10 === 2)    suffix = 'nd';
            else if (d % 10 === 3)    suffix = 'rd';
            else                      suffix = 'th';
            result.push({ label: `${d}${suffix}${d === 1 ? ' (default)' : ''}`, value: String(d) });
        }
        return result;
    }

    get formattedTemplates() {
        const dowNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return this.recurringTemplates.map(tmpl => {
            const freq = tmpl.Frequency__c || 'Monthly';
            let dayLabel = '';
            if (tmpl.Spawn_Day__c != null) {
                const d = parseInt(tmpl.Spawn_Day__c, 10);
                if (freq === 'Monthly') {
                    let suffix;
                    if (d >= 11 && d <= 13)   suffix = 'th';
                    else if (d % 10 === 1)    suffix = 'st';
                    else if (d % 10 === 2)    suffix = 'nd';
                    else if (d % 10 === 3)    suffix = 'rd';
                    else                      suffix = 'th';
                    dayLabel = ` · ${d}${suffix}`;
                } else {
                    dayLabel = ` · ${dowNames[d] || ''}`;
                }
            }
            return { ...tmpl, frequencyLabel: freq + dayLabel };
        });
    }

    get userOptions() {
        const opts = [];
        if (this.activeUsers && this.activeUsers.data) {
            this.activeUsers.data.forEach(u => opts.push({ label: u.Name, value: u.Id }));
        }
        return opts;
    }

    get filteredEditUserOptions() {
        const search = (this.editAssignedLabel || '').toLowerCase().trim();
        if (!search) return this.userOptions;
        return this.userOptions.filter(u => u.label.toLowerCase().includes(search));
    }

    get filteredNewUserOptions() {
        const search = (this.newAssignedLabel || '').toLowerCase().trim();
        if (!search) return this.userOptions;
        return this.userOptions.filter(u => u.label.toLowerCase().includes(search));
    }

    get editFilteredUsersEmpty() { return this.filteredEditUserOptions.length === 0; }
    get newFilteredUsersEmpty()  { return this.filteredNewUserOptions.length === 0; }

    get editComments() {
        const data = (this._wiredCommentsResult && this._wiredCommentsResult.data) || [];
        return data.map(c => ({
            ...c,
            formattedDate: new Date(c.CreatedDate).toLocaleString('en-US', {
                month: 'short', day: 'numeric', year: 'numeric',
                hour: 'numeric', minute: '2-digit'
            })
        }));
    }

    get hasComments() {
        return this.editComments.length > 0;
    }

    get syncedFiles() {
        return Array.isArray(this._wiredSyncedFilesResult) ? this._wiredSyncedFilesResult : [];
    }

    get hasSyncedFiles() {
        return this.syncedFiles.length > 0;
    }

    get newTaskSaved() {
        return !!this._newTaskSavedId;
    }

    get editSmartGoalChips() {
        return this.editSmartGoalIds.map(id => {
            const opt = (this.smartGoals && this.smartGoals.data || []).find(g => g.Id === id);
            return { id, label: opt ? (opt.Initiative_Name__c || opt.Name) : id };
        });
    }

    get filteredEditSmartGoalOptions() {
        const search = (this.editSmartGoalSearch || '').toLowerCase();
        return (this.smartGoals && this.smartGoals.data || [])
            .filter(g => !this.editSmartGoalIds.includes(g.Id) &&
                         (!search || (g.Initiative_Name__c || g.Name || '').toLowerCase().includes(search)))
            .map(g => ({ value: g.Id, label: g.Initiative_Name__c || g.Name }));
    }

    get editSmartGoalsEmpty() { return this.filteredEditSmartGoalOptions.length === 0; }

    get newSmartGoalChips() {
        return this.newSmartGoalIds.map(id => {
            const opt = (this.smartGoals && this.smartGoals.data || []).find(g => g.Id === id);
            return { id, label: opt ? (opt.Initiative_Name__c || opt.Name) : id };
        });
    }

    get filteredNewSmartGoalOptions() {
        const search = (this.newSmartGoalSearch || '').toLowerCase();
        return (this.smartGoals && this.smartGoals.data || [])
            .filter(g => !this.newSmartGoalIds.includes(g.Id) &&
                         (!search || (g.Initiative_Name__c || g.Name || '').toLowerCase().includes(search)))
            .map(g => ({ value: g.Id, label: g.Initiative_Name__c || g.Name }));
    }

    get newSmartGoalsEmpty() { return this.filteredNewSmartGoalOptions.length === 0; }

    get editRelatedTaskChips() {
        const allData = (this._wiredTasksResult && this._wiredTasksResult.data) || [];
        return this.editRelatedTaskIds.map(id => {
            const t = allData.find(tk => tk.Id === id);
            return { id, label: t ? `[${t.Task_Number__c || '?'}] ${t.Subject}` : id };
        });
    }

    get filteredEditRelatedOptions() {
        const search = (this.editRelatedTaskSearch || '').toLowerCase();
        const allData = (this._wiredTasksResult && this._wiredTasksResult.data) || [];
        return allData
            .filter(t => t.Id !== this._editTaskId &&
                         !this.editRelatedTaskIds.includes(t.Id) &&
                         (!search || (t.Subject || '').toLowerCase().includes(search) ||
                                     (t.Task_Number__c || '').toLowerCase().includes(search)))
            .map(t => ({ value: t.Id, label: `[${t.Task_Number__c || '?'}] ${t.Subject}` }))
            .slice(0, 10);
    }

    get editRelatedTasksEmpty() { return this.filteredEditRelatedOptions.length === 0; }

    get newRelatedTaskChips() {
        const allData = (this._wiredTasksResult && this._wiredTasksResult.data) || [];
        return this.newRelatedTaskIds.map(id => {
            const t = allData.find(tk => tk.Id === id);
            return { id, label: t ? `[${t.Task_Number__c || '?'}] ${t.Subject}` : id };
        });
    }

    get filteredNewRelatedOptions() {
        const search = (this.newRelatedTaskSearch || '').toLowerCase();
        const allData = (this._wiredTasksResult && this._wiredTasksResult.data) || [];
        return allData
            .filter(t => !this.newRelatedTaskIds.includes(t.Id) &&
                         (!search || (t.Subject || '').toLowerCase().includes(search) ||
                                     (t.Task_Number__c || '').toLowerCase().includes(search)))
            .map(t => ({ value: t.Id, label: `[${t.Task_Number__c || '?'}] ${t.Subject}` }))
            .slice(0, 10);
    }

    get newRelatedTasksEmpty() { return this.filteredNewRelatedOptions.length === 0; }

    get templateSmartGoalChips() {
        return this.templateSmartGoalIds.map(id => {
            const opt = (this.smartGoals && this.smartGoals.data || []).find(g => g.Id === id);
            return { id, label: opt ? (opt.Initiative_Name__c || opt.Name) : id };
        });
    }

    get filteredTemplateSmartGoalOptions() {
        const search = (this.templateSmartGoalSearch || '').toLowerCase();
        return (this.smartGoals && this.smartGoals.data || [])
            .filter(g => !this.templateSmartGoalIds.includes(g.Id) &&
                         (!search || (g.Initiative_Name__c || g.Name || '').toLowerCase().includes(search)))
            .map(g => ({ value: g.Id, label: g.Initiative_Name__c || g.Name }));
    }

    get templateSmartGoalsEmpty() { return this.filteredTemplateSmartGoalOptions.length === 0; }

    get editProjectChips() {
        return this.editProjectIds.map(id => {
            const p = (this.projects.data || []).find(proj => proj.Id === id);
            return { id, label: p ? p.Name : id };
        });
    }

    get filteredEditProjectOptions() {
        const search = (this.editProjectSearch || '').toLowerCase();
        return (this.projects.data || [])
            .filter(p => !this.editProjectIds.includes(p.Id) &&
                         (!search || p.Name.toLowerCase().includes(search)))
            .map(p => ({ value: p.Id, label: p.Name }));
    }

    get editProjectsEmpty() { return this.filteredEditProjectOptions.length === 0; }

    get newProjectChips() {
        return this.newProjectIds.map(id => {
            const p = (this.projects.data || []).find(proj => proj.Id === id);
            return { id, label: p ? p.Name : id };
        });
    }

    get filteredNewProjectOptions() {
        const search = (this.newProjectSearch || '').toLowerCase();
        return (this.projects.data || [])
            .filter(p => !this.newProjectIds.includes(p.Id) &&
                         (!search || p.Name.toLowerCase().includes(search)))
            .map(p => ({ value: p.Id, label: p.Name }));
    }

    get newProjectsEmpty() { return this.filteredNewProjectOptions.length === 0; }

    get templateProjectChips() {
        return this.templateProjectIds.map(id => {
            const p = (this.projects.data || []).find(proj => proj.Id === id);
            return { id, label: p ? p.Name : id };
        });
    }

    get filteredTemplateProjectOptions() {
        const search = (this.templateProjectSearch || '').toLowerCase();
        return (this.projects.data || [])
            .filter(p => !this.templateProjectIds.includes(p.Id) &&
                         (!search || p.Name.toLowerCase().includes(search)))
            .map(p => ({ value: p.Id, label: p.Name }));
    }

    get templateProjectsEmpty() { return this.filteredTemplateProjectOptions.length === 0; }

    // ── Tag getters ──────────────────────────────────────────────────────────
    get filteredEditTaskTagOptions() {
        const selectedIds = this.editTaskTagChips.map(t => t.id);
        return (this.editTaskTagOptions || [])
            .filter(t => !selectedIds.includes(t.Id))
            .map(t => ({ value: t.Id, label: t.Name }));
    }
    get editTaskTagCreateLabel() {
        const s = (this.editTaskTagSearch || '').trim();
        if (!s) return null;
        const exact = (this.editTaskTagOptions || []).some(t => t.Name.toLowerCase() === s.toLowerCase());
        const chipped = this.editTaskTagChips.some(t => t.label.toLowerCase() === s.toLowerCase());
        return (!exact && !chipped) ? s : null;
    }
    get editTaskTagsEmpty() {
        return this.filteredEditTaskTagOptions.length === 0 && !this.editTaskTagCreateLabel;
    }

    get filteredNewTaskTagOptions() {
        const selectedIds = this.newTaskTagChips.map(t => t.id);
        return (this.newTaskTagOptions || [])
            .filter(t => !selectedIds.includes(t.Id))
            .map(t => ({ value: t.Id, label: t.Name }));
    }
    get newTaskTagCreateLabel() {
        const s = (this.newTaskTagSearch || '').trim();
        if (!s) return null;
        const exact = (this.newTaskTagOptions || []).some(t => t.Name.toLowerCase() === s.toLowerCase());
        const chipped = this.newTaskTagChips.some(t => t.label.toLowerCase() === s.toLowerCase());
        return (!exact && !chipped) ? s : null;
    }
    get newTaskTagsEmpty() {
        return this.filteredNewTaskTagOptions.length === 0 && !this.newTaskTagCreateLabel;
    }

    get filteredTemplateTagOptions() {
        const selectedIds = this.templateTagChips.map(t => t.id);
        return (this.templateTagOptions || [])
            .filter(t => !selectedIds.includes(t.Id))
            .map(t => ({ value: t.Id, label: t.Name }));
    }
    get templateTagCreateLabel() {
        const s = (this.templateTagSearch || '').trim();
        if (!s) return null;
        const exact = (this.templateTagOptions || []).some(t => t.Name.toLowerCase() === s.toLowerCase());
        const chipped = this.templateTagChips.some(t => t.label.toLowerCase() === s.toLowerCase());
        return (!exact && !chipped) ? s : null;
    }
    get templateTagsEmpty() {
        return this.filteredTemplateTagOptions.length === 0 && !this.templateTagCreateLabel;
    }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx', '.xls', '.xlsx', '.txt', '.csv', '.zip'];
    }

    get filteredMentionUsers() {
        const q = (this._mentionQuery || '').toLowerCase();
        return (this.activeUsers && this.activeUsers.data || [])
            .filter(u => !q || u.Name.toLowerCase().includes(q))
            .map(u => ({ value: u.Id, label: u.Name }))
            .slice(0, 8);
    }

    get filteredEditDescMentionUsers() {
        const q = (this._editDescMentionQuery || '').toLowerCase();
        return (this.activeUsers && this.activeUsers.data || [])
            .filter(u => !q || u.Name.toLowerCase().includes(q))
            .map(u => ({ value: u.Id, label: u.Name }))
            .slice(0, 8);
    }

    get filteredNewDescMentionUsers() {
        const q = (this._newDescMentionQuery || '').toLowerCase();
        return (this.activeUsers && this.activeUsers.data || [])
            .filter(u => !q || u.Name.toLowerCase().includes(q))
            .map(u => ({ value: u.Id, label: u.Name }))
            .slice(0, 8);
    }

    get filteredTmplDescMentionUsers() {
        const q = (this._tmplDescMentionQuery || '').toLowerCase();
        return (this.activeUsers && this.activeUsers.data || [])
            .filter(u => !q || u.Name.toLowerCase().includes(q))
            .map(u => ({ value: u.Id, label: u.Name }))
            .slice(0, 8);
    }

    // ─── Filter handlers ──────────────────────────────────────────────────────
    handleProjectChange(event)          { this.selectedProjectId   = event.detail.value; }
    handleMonthChange(event) {
        if (event.detail.value === '__picker__') {
            this.showMonthPicker = true;
        } else {
            this.selectedMonth = event.detail.value;
            this.showMonthPicker = false;
        }
    }
    get pickerYearOptions() {
        const opts = [];
        const currentYear = new Date().getFullYear();
        for (let y = currentYear + 1; y >= currentYear - 5; y--) {
            opts.push({ label: String(y), value: String(y) });
        }
        return opts;
    }
    get pickerMonthOptions() {
        return MONTH_NAMES.map((name, i) => ({ label: name, value: String(i + 1) }));
    }
    handlePickerYearChange(event) {
        this.pickerYear = event.detail.value;
    }
    handlePickerMonthChange(event) {
        this.pickerMonth = event.detail.value;
    }
    handlePickerApply() {
        const mo = this.pickerMonth.padStart(2, '0');
        this.selectedMonth = `${this.pickerYear}-${mo}`;
        this.showMonthPicker = false;
    }
    handleMonthPickerCancel() {
        this.showMonthPicker = false;
    }
    // Assign to Month — new task form
    handleToggleNewAssign()           { this.newAssignOpen   = true; }
    handleClearNewAssign()            { this.newAssignOpen   = false; }
    handleNewAssignYearChange(event)  { this.newAssignYear   = event.detail.value; }
    handleNewAssignMonthChange(event) { this.newAssignMonth  = event.detail.value; }
    // Assign to Month — edit task form
    handleToggleEditAssign()           { this.editAssignOpen  = true; }
    handleClearEditAssignMonth() {
        this.editAssignOpen  = false;
        this.editAssignYear  = '';
        this.editAssignMonth = '';
    }
    handleEditAssignYearChange(event)  { this.editAssignYear  = event.detail.value; }
    handleEditAssignMonthChange(event) { this.editAssignMonth = event.detail.value; }
    // Column select-all checkboxes
    get queueAllSelected()      { return this.queueTasks.length > 0      && this.queueTasks.every(t => this.selectedTaskIds.includes(t.Id)); }
    get inProgressAllSelected() { return this.inProgressTasks.length > 0 && this.inProgressTasks.every(t => this.selectedTaskIds.includes(t.Id)); }
    get completeAllSelected()   { return this.completeTasks.length > 0   && this.completeTasks.every(t => this.selectedTaskIds.includes(t.Id)); }
    handleSelectAllColumn(event) {
        const col = event.currentTarget.dataset.col;
        const colTasks = col === 'Queue' ? this.queueTasks
                       : col === 'In Progress' ? this.inProgressTasks
                       : this.completeTasks;
        const colIds = colTasks.map(t => t.Id);
        const allSelected = colIds.every(id => this.selectedTaskIds.includes(id));
        if (allSelected) {
            this.selectedTaskIds = this.selectedTaskIds.filter(id => !colIds.includes(id));
        } else {
            const toAdd = colIds.filter(id => !this.selectedTaskIds.includes(id));
            this.selectedTaskIds = [...this.selectedTaskIds, ...toAdd];
        }
    }
    // Bulk assign to month
    handleBulkAssignYearChange(event)  { this.bulkAssignYear  = event.detail.value; }
    handleBulkAssignMonthChange(event) { this.bulkAssignMonth = event.detail.value; }
    handleToggleBulkAssignPicker() { this.showBulkAssignPicker = !this.showBulkAssignPicker; }
    handleBulkAssignApply() {
        if (!this.selectedTaskIds.length) return;
        const mo = (this.bulkAssignMonth || '1').padStart(2, '0');
        const targetMonth = `${this.bulkAssignYear}-${mo}-01`;
        this.bulkAssignLoading = true;
        bulkAssignToMonth({ taskIds: this.selectedTaskIds, targetMonth })
            .then(() => {
                this.showToast('Updated', `${this.selectedTaskIds.length} task(s) assigned to ${MONTH_NAMES[parseInt(mo, 10) - 1]} ${this.bulkAssignYear}.`, 'success');
                this.selectedTaskIds = [];
                this.showBulkAssignPicker = false;
                this.selectMode = false;
                return refreshApex(this._wiredTasksResult);
            })
            .catch(e => this.showError('Bulk assign failed', e))
            .finally(() => { this.bulkAssignLoading = false; });
    }
    handleSmartGoalFilterChange(event)  { this.selectedSmartGoalId = event.detail.value; }
    handlePriorityFilterChange(event)   { this.selectedPriority    = event.detail.value; }
    handleSearchInput(event)            { this.searchKeyword        = event.target.value; }

    // ─── Sort handler ─────────────────────────────────────────────────────────
    handleSortField(event) {
        const field = event.currentTarget.dataset.field;
        const col   = event.currentTarget.dataset.col;
        const cur   = this.columnSorts[col];
        const newDir = cur.field === field ? (cur.dir === 'asc' ? 'desc' : 'asc') : 'asc';
        this.columnSorts = { ...this.columnSorts, [col]: { field, dir: newDir } };
    }

    // ─── Drag and Drop ────────────────────────────────────────────────────────
    handleDragStart(event) {
        this._dragTaskId = event.currentTarget.dataset.id;
        event.dataTransfer.effectAllowed = 'move';
    }

    handleDragOver(event) {
        event.preventDefault();
        event.currentTarget.classList.add('drag-over');
        event.dataTransfer.dropEffect = 'move';
    }

    handleDragLeave(event) {
        // only remove when leaving the column itself, not a child element inside it
        if (!event.currentTarget.contains(event.relatedTarget)) {
            event.currentTarget.classList.remove('drag-over');
        }
    }

    handleDragEnd() {
        // safety net: clear any column that still has the class (cancelled drag, Escape key, etc.)
        this.template.querySelectorAll('.kanban-column.drag-over').forEach(col => {
            col.classList.remove('drag-over');
        });
    }

    handleDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('drag-over');
        const newStatus = event.currentTarget.dataset.status;
        if (!this._dragTaskId || !newStatus) return;

        const task = this.allTasks.find(t => t.Id === this._dragTaskId);
        if (!task || task.Kanban_Status__c === newStatus) return;

        updateTaskStatus({ taskId: this._dragTaskId, newStatus })
            .then(() => refreshApex(this._wiredTasksResult))
            .catch(err => this.showError('Failed to update status', err));

        this._dragTaskId = null;
    }

    // ─── New Task Modal ───────────────────────────────────────────────────────
    handleNewTask() {
        this.newTask = { Subject: '', Kanban_Status__c: 'Queue', Priority: 'Normal', ActivityDate: '', Description: '', timeSpent: null, assignedToId: '' };
        this.newAssignOpen  = false;
        this.newAssignedLabel = '';
        this._newTaskSavedId = null;
        this.newTaskHasAttachments = false;
        this.newSmartGoalIds = [];
        this.newSmartGoalSearch = '';
        this.showNewSmartGoalDropdown = false;
        this.newRelatedTaskIds = [];
        this.newRelatedTaskSearch = '';
        this.showNewRelatedDropdown = false;
        this.newProjectIds = [];
        this.newProjectSearch = '';
        this.showNewProjectDropdown = false;
        this.newTaskTagChips = [];
        this.newTaskTagSearch = '';
        this.showNewTaskTagDropdown = false;
        this.newTaskTagOptions = [];
        this._newDescMentionedIds = [];
        this.showNewDescDropdown = false;
        this._newDescMentionQuery = '';
        this.showNewTaskModal = true;
    }

    handleCloseModal() {
        this.showNewTaskModal = false;
        this.newAssignOpen    = false;
        this.newAssignedLabel = '';
        this.showNewAssignedDropdown = false;
        this._newTaskSavedId = null;
        this.newTaskHasAttachments = false;
        this.newSmartGoalIds = [];
        this.newSmartGoalSearch = '';
        this.showNewSmartGoalDropdown = false;
        this.newRelatedTaskIds = [];
        this.newRelatedTaskSearch = '';
        this.showNewRelatedDropdown = false;
        this.newProjectIds = [];
        this.newProjectSearch = '';
        this.showNewProjectDropdown = false;
        this.newTaskTagChips = [];
        this.newTaskTagSearch = '';
        this.showNewTaskTagDropdown = false;
        this.newTaskTagOptions = [];
        this._newDescMentionedIds = [];
        this.showNewDescDropdown = false;
        this._newDescMentionQuery = '';
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const raw   = event.detail.value;
        const value = field === 'timeSpent'
            ? (raw !== '' && raw != null ? parseFloat(raw) : null)
            : raw;
        this.newTask = { ...this.newTask, [field]: value };
    }

    handleSaveTask() {
        if (!this.newTask.Subject) {
            this.showError('Title is required', null);
            return;
        }
        const newAssignMo   = (this.newAssignMonth || '1').padStart(2, '0');
        const newAssignDate = this.newAssignOpen
            ? `${this.newAssignYear}-${newAssignMo}-01`
            : null;
        createTask({
            subject:       this.newTask.Subject,
            projectId:     this.newProjectIds[0]     || null,
            kanbanStatus:  this.newTask.Kanban_Status__c,
            dueDate:       this.newTask.ActivityDate || null,
            description:   this.newTask.Description,
            priority:      this.newTask.Priority,
            smartGoalIds:  this.newSmartGoalIds,
            timeSpent:     this.newTask.timeSpent    != null ? this.newTask.timeSpent : null,
            assignedToId:  this.newTask.assignedToId || null,
            assignToMonth: newAssignDate
        })
        .then(result => {
            this._newTaskSavedId = result.Id;
            const taskId = result.Id;
            return saveTaskRelations({ taskId, relatedTaskIds: this.newRelatedTaskIds })
                .then(() => saveTaskProjects({ taskId, projectIds: this.newProjectIds }))
                .then(() => saveTaskTags({ taskId, tagIds: this.newTaskTagChips.map(t => t.id) }))
                .then(() => {
                    if (this._newDescMentionedIds.length > 0) {
                        return saveMentions({ taskId, userIds: this._newDescMentionedIds });
                    }
                });
        })
        .then(() => {
            this._newDescMentionedIds = [];
            this.showNewDescDropdown = false;
            if (this.newTaskHasAttachments) {
                this.newTaskHasAttachments = false;
                // Modal stays open — _newTaskSavedId set, newTaskSaved getter shows file uploader
            } else {
                this._newTaskSavedId = null;
                this.showNewTaskModal = false;
                this.newAssignedLabel = '';
                this.showNewAssignedDropdown = false;
                this.newSmartGoalIds = [];
                this.newSmartGoalSearch = '';
                this.showNewSmartGoalDropdown = false;
                this.newRelatedTaskIds = [];
                this.newRelatedTaskSearch = '';
                this.showNewRelatedDropdown = false;
                this.newProjectIds = [];
                this.newProjectSearch = '';
                this.showNewProjectDropdown = false;
                this.newTaskTagChips = [];
                this.newTaskTagSearch = '';
                this.showNewTaskTagDropdown = false;
                this.newTaskTagOptions = [];
                this.showToast('Task Created', 'Task saved successfully.', 'success');
            }
            return refreshApex(this._wiredTasksResult);
        })
        .catch(err => this.showError('Failed to create task', err));
    }

    handleNewTaskHasAttachmentsChange(event) {
        this.newTaskHasAttachments = event.detail.checked;
    }

    handleNewTaskDone() {
        this.showNewTaskModal = false;
        this._newTaskSavedId = null;
        this.newTaskHasAttachments = false;
        this.newAssignedLabel = '';
        this.showNewAssignedDropdown = false;
        this.newSmartGoalIds = [];
        this.newSmartGoalSearch = '';
        this.showNewSmartGoalDropdown = false;
        this.newRelatedTaskIds = [];
        this.newRelatedTaskSearch = '';
        this.showNewRelatedDropdown = false;
        this.newProjectIds = [];
        this.newProjectSearch = '';
        this.showNewProjectDropdown = false;
        this.newTaskTagChips = [];
        this.newTaskTagSearch = '';
        this.showNewTaskTagDropdown = false;
        this.newTaskTagOptions = [];
        this._newDescMentionedIds = [];
        this.showNewDescDropdown = false;
        this._newDescMentionQuery = '';
    }

    handleNewTaskUploadFinished() {
        syncTaskFilesToSharePoint({ taskId: this._newTaskSavedId })
            .then(() => {
                this.showToast('Syncing to SharePoint', 'File is being moved to SharePoint.', 'info');
            })
            .catch(err => {
                this.showError('SharePoint sync failed', err);
            });
    }

    // ─── Edit Task Modal ──────────────────────────────────────────────────────
    handleEdit(event) {
        const taskId = event.currentTarget.dataset.id;
        const allData = (this._wiredTasksResult && this._wiredTasksResult.data) || [];
        const task = allData.find(t => t.Id === taskId);
        if (!task) return;
        this.editTask = {
            Id:               task.Id,
            Subject:          task.Subject             || '',
            Kanban_Status__c: task.Kanban_Status__c    || 'Queue',
            Priority:         task.Priority            || 'Normal',
            ActivityDate:     task.ActivityDate        || '',
            Description:      task.Description         || '',
            timeSpent:        task.Time_Spent__c       != null ? task.Time_Spent__c : '',
            assignedToId:     task.OwnerId             || ''
        };
        // Set edit assign month — only open picker if task already has a value
        if (task.Assign_To_Month__c) {
            const [ey, em] = task.Assign_To_Month__c.split('-');
            this.editAssignYear  = ey;
            this.editAssignMonth = String(parseInt(em, 10));
            this.editAssignOpen  = true;
        } else {
            // Pre-load defaults for when user opens it, but keep it closed
            const created = task.CreatedDate ? new Date(task.CreatedDate) : new Date();
            const next    = new Date(created.getFullYear(), created.getMonth() + 1, 1);
            this.editAssignYear  = String(next.getFullYear());
            this.editAssignMonth = String(next.getMonth() + 1);
            this.editAssignOpen  = false;
        }
        this.editAssignedLabel = (task.Owner && task.Owner.Name) ? task.Owner.Name : '';
        this._editTaskId = task.Id;
        this.newCommentText = '';
        this.showMentionDropdown = false;
        this._mentionQuery = '';
        this._mentionAtStart = 0;
        this._mentionedUserIds = [];
        this._editDescMentionedIds = [];
        this.showEditDescDropdown = false;
        this._editDescMentionQuery = '';
        this._wiredSyncedFilesResult = [];
        this.editSmartGoalIds = [];
        this.editSmartGoalSearch = '';
        this.showEditSmartGoalDropdown = false;
        this.editRelatedTaskIds = [];
        this.editRelatedTaskSearch = '';
        this.showEditRelatedDropdown = false;
        this.editProjectIds = [];
        this.editProjectSearch = '';
        this.showEditProjectDropdown = false;
        this.editTaskTagChips = [];
        this.editTaskTagSearch = '';
        this.showEditTaskTagDropdown = false;
        this.editTaskTagOptions = [];
        this.showEditModal = true;
        this.loadSyncedFiles();
        this.loadTaskSmartGoals();
        this.loadRelatedTasks();
        this.loadTaskProjects();
        this.loadTaskTags();
    }

    handleCloseEditModal() {
        this.showEditModal   = false;
        this.editAssignOpen  = false;
        this._editTaskId = null;
        this.newCommentText = '';
        this.showMentionDropdown = false;
        this._mentionQuery = '';
        this._mentionAtStart = 0;
        this._mentionedUserIds = [];
        this._editDescMentionedIds = [];
        this.showEditDescDropdown = false;
        this._editDescMentionQuery = '';
        this.editAssignedLabel = '';
        this.showEditAssignedDropdown = false;
        this.isSyncing = false;
        this._wiredSyncedFilesResult = [];
        this.editSmartGoalIds = [];
        this.editSmartGoalSearch = '';
        this.showEditSmartGoalDropdown = false;
        this.editRelatedTaskIds = [];
        this.editRelatedTaskSearch = '';
        this.showEditRelatedDropdown = false;
        this.editProjectIds = [];
        this.editProjectSearch = '';
        this.showEditProjectDropdown = false;
        this.editTaskTagChips = [];
        this.editTaskTagSearch = '';
        this.showEditTaskTagDropdown = false;
        this.editTaskTagOptions = [];
    }

    handleEditFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const raw   = event.detail.value;
        const value = field === 'timeSpent'
            ? (raw !== '' && raw != null ? parseFloat(raw) : null)
            : raw;
        this.editTask = { ...this.editTask, [field]: value };
    }

    handleEditAssignedSearch(event) {
        this.editAssignedLabel = event.detail.value;
        this.showEditAssignedDropdown = true;
    }

    handleEditAssignedFocus() {
        this.showEditAssignedDropdown = true;
    }

    handleEditAssignedBlur() {
        // Delay so onmousedown on an option fires before blur closes the list
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.showEditAssignedDropdown = false;
            if (!this.editAssignedLabel) {
                this.editTask = { ...this.editTask, assignedToId: '' };
            } else {
                const selected = this.userOptions.find(u => u.value === this.editTask.assignedToId);
                this.editAssignedLabel = selected ? selected.label : '';
            }
        }, 200);
    }

    handleEditAssignedSelect(event) {
        const id    = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        this.editTask = { ...this.editTask, assignedToId: id };
        this.editAssignedLabel = label;
        this.showEditAssignedDropdown = false;
    }

    handleNewAssignedSearch(event) {
        this.newAssignedLabel = event.detail.value;
        this.showNewAssignedDropdown = true;
    }

    handleNewAssignedFocus() {
        this.showNewAssignedDropdown = true;
    }

    handleNewAssignedBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.showNewAssignedDropdown = false;
            if (!this.newAssignedLabel) {
                this.newTask = { ...this.newTask, assignedToId: '' };
            } else {
                const selected = this.userOptions.find(u => u.value === this.newTask.assignedToId);
                this.newAssignedLabel = selected ? selected.label : '';
            }
        }, 200);
    }

    handleNewAssignedSelect(event) {
        const id    = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        this.newTask = { ...this.newTask, assignedToId: id };
        this.newAssignedLabel = label;
        this.showNewAssignedDropdown = false;
    }

    // ─── Smart Goal multi-select (Edit) ──────────────────────────────────────
    handleEditSmartGoalSearch(event) {
        this.editSmartGoalSearch = event.detail.value;
        this.showEditSmartGoalDropdown = true;
    }

    handleEditSmartGoalFocus() {
        this.showEditSmartGoalDropdown = true;
    }

    handleEditSmartGoalBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showEditSmartGoalDropdown = false; }, 200);
    }

    handleEditSmartGoalSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.editSmartGoalIds.includes(id)) {
            this.editSmartGoalIds = [...this.editSmartGoalIds, id];
        }
        this.editSmartGoalSearch = '';
        this.showEditSmartGoalDropdown = false;
    }

    handleEditSmartGoalRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.editSmartGoalIds = this.editSmartGoalIds.filter(v => v !== id);
    }

    // ─── Smart Goal multi-select (New Task) ──────────────────────────────────
    handleNewSmartGoalSearch(event) {
        this.newSmartGoalSearch = event.detail.value;
        this.showNewSmartGoalDropdown = true;
    }

    handleNewSmartGoalFocus() {
        this.showNewSmartGoalDropdown = true;
    }

    handleNewSmartGoalBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showNewSmartGoalDropdown = false; }, 200);
    }

    handleNewSmartGoalSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.newSmartGoalIds.includes(id)) {
            this.newSmartGoalIds = [...this.newSmartGoalIds, id];
        }
        this.newSmartGoalSearch = '';
        this.showNewSmartGoalDropdown = false;
    }

    handleNewSmartGoalRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.newSmartGoalIds = this.newSmartGoalIds.filter(v => v !== id);
    }

    // ─── Related Tasks multi-select (Edit) ───────────────────────────────────
    handleEditRelatedSearch(event) {
        this.editRelatedTaskSearch = event.detail.value;
        this.showEditRelatedDropdown = true;
    }

    handleEditRelatedFocus() {
        this.showEditRelatedDropdown = true;
    }

    handleEditRelatedBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showEditRelatedDropdown = false; }, 200);
    }

    handleEditRelatedSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.editRelatedTaskIds.includes(id)) {
            this.editRelatedTaskIds = [...this.editRelatedTaskIds, id];
        }
        this.editRelatedTaskSearch = '';
        this.showEditRelatedDropdown = false;
    }

    handleEditRelatedRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.editRelatedTaskIds = this.editRelatedTaskIds.filter(v => v !== id);
    }

    // ─── Related Tasks multi-select (New) ────────────────────────────────────
    handleNewRelatedSearch(event) {
        this.newRelatedTaskSearch = event.detail.value;
        this.showNewRelatedDropdown = true;
    }

    handleNewRelatedFocus() {
        this.showNewRelatedDropdown = true;
    }

    handleNewRelatedBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showNewRelatedDropdown = false; }, 200);
    }

    handleNewRelatedSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.newRelatedTaskIds.includes(id)) {
            this.newRelatedTaskIds = [...this.newRelatedTaskIds, id];
        }
        this.newRelatedTaskSearch = '';
        this.showNewRelatedDropdown = false;
    }

    handleNewRelatedRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.newRelatedTaskIds = this.newRelatedTaskIds.filter(v => v !== id);
    }

    // ─── Project multi-select (Edit) ─────────────────────────────────────────
    handleEditProjectSearch(event) {
        this.editProjectSearch = event.detail.value;
        this.showEditProjectDropdown = true;
    }

    handleEditProjectFocus() {
        this.showEditProjectDropdown = true;
    }

    handleEditProjectBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showEditProjectDropdown = false; }, 200);
    }

    handleEditProjectSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.editProjectIds.includes(id)) {
            this.editProjectIds = [...this.editProjectIds, id];
        }
        this.editProjectSearch = '';
        this.showEditProjectDropdown = false;
    }

    handleEditProjectRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.editProjectIds = this.editProjectIds.filter(v => v !== id);
    }

    // ─── Project multi-select (New Task) ─────────────────────────────────────
    handleNewProjectSearch(event) {
        this.newProjectSearch = event.detail.value;
        this.showNewProjectDropdown = true;
    }

    handleNewProjectFocus() {
        this.showNewProjectDropdown = true;
    }

    handleNewProjectBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showNewProjectDropdown = false; }, 200);
    }

    handleNewProjectSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.newProjectIds.includes(id)) {
            this.newProjectIds = [...this.newProjectIds, id];
        }
        this.newProjectSearch = '';
        this.showNewProjectDropdown = false;
    }

    handleNewProjectRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.newProjectIds = this.newProjectIds.filter(v => v !== id);
    }

    // ─── Project multi-select (Recurring Template) ───────────────────────────
    handleTemplateProjectSearch(event) {
        this.templateProjectSearch = event.detail.value;
        this.showTemplateProjectDropdown = true;
    }

    handleTemplateProjectFocus() {
        this.showTemplateProjectDropdown = true;
    }

    handleTemplateProjectBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showTemplateProjectDropdown = false; }, 200);
    }

    handleTemplateProjectSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.templateProjectIds.includes(id)) {
            this.templateProjectIds = [...this.templateProjectIds, id];
        }
        this.templateProjectSearch = '';
        this.showTemplateProjectDropdown = false;
    }

    handleTemplateProjectRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.templateProjectIds = this.templateProjectIds.filter(v => v !== id);
    }

    // ── Tag handlers ─────────────────────────────────────────────────────────
    _tagSearch(query, context) {
        const s = (query || '').trim();
        if (!s) { this[`${context}TagOptions`] = []; this[`show${context.charAt(0).toUpperCase()+context.slice(1)}TagDropdown`] = false; return; }
        searchTags({ query: s })
            .then(data => { this[`${context}TagOptions`] = data || []; this[`show${context.charAt(0).toUpperCase()+context.slice(1)}TagDropdown`] = true; })
            .catch(() => {});
    }
    _tagSelect(id, label, context) {
        const chipsProp = `${context}TagChips`;
        const searchProp = `${context}TagSearch`;
        const dropProp = `show${context.charAt(0).toUpperCase()+context.slice(1)}TagDropdown`;
        const optsProp = `${context}TagOptions`;
        if (id === '__create__') {
            const name = (this[searchProp] || '').trim();
            ensureTag({ tagName: name })
                .then(tagId => {
                    if (tagId && !this[chipsProp].some(t => t.id === tagId)) {
                        this[chipsProp] = [...this[chipsProp], { id: tagId, label: name }];
                    }
                    this[searchProp] = ''; this[dropProp] = false; this[optsProp] = [];
                })
                .catch(err => this.showError('Failed to create tag', err));
        } else {
            if (!this[chipsProp].some(t => t.id === id)) {
                this[chipsProp] = [...this[chipsProp], { id, label }];
            }
            this[searchProp] = ''; this[dropProp] = false; this[optsProp] = [];
        }
    }

    handleEditTaskTagSearch(event)   { this.editTaskTagSearch   = event.target.value; this._tagSearch(event.target.value, 'editTask'); }
    handleEditTaskTagFocus()         { if ((this.editTaskTagSearch||'').trim()) this.showEditTaskTagDropdown = true; }
    handleEditTaskTagBlur()          { this.showEditTaskTagDropdown = false; }
    handleEditTaskTagSelect(event)   { this._tagSelect(event.currentTarget.dataset.id, event.currentTarget.dataset.label, 'editTask'); }
    handleEditTaskTagRemove(event)   { const id = event.currentTarget.dataset.id; this.editTaskTagChips = this.editTaskTagChips.filter(t => t.id !== id); }

    handleNewTaskTagSearch(event)    { this.newTaskTagSearch    = event.target.value; this._tagSearch(event.target.value, 'newTask'); }
    handleNewTaskTagFocus()          { if ((this.newTaskTagSearch||'').trim()) this.showNewTaskTagDropdown = true; }
    handleNewTaskTagBlur()           { this.showNewTaskTagDropdown = false; }
    handleNewTaskTagSelect(event)    { this._tagSelect(event.currentTarget.dataset.id, event.currentTarget.dataset.label, 'newTask'); }
    handleNewTaskTagRemove(event)    { const id = event.currentTarget.dataset.id; this.newTaskTagChips = this.newTaskTagChips.filter(t => t.id !== id); }

    handleTemplateTagSearch(event)   { this.templateTagSearch   = event.target.value; this._tagSearch(event.target.value, 'template'); }
    handleTemplateTagFocus()         { if ((this.templateTagSearch||'').trim()) this.showTemplateTagDropdown = true; }
    handleTemplateTagBlur()          { this.showTemplateTagDropdown = false; }
    handleTemplateTagSelect(event)   { this._tagSelect(event.currentTarget.dataset.id, event.currentTarget.dataset.label, 'template'); }
    handleTemplateTagRemove(event)   { const id = event.currentTarget.dataset.id; this.templateTagChips = this.templateTagChips.filter(t => t.id !== id); }

    // ─── Description @mention helpers ────────────────────────────────────────
    _detectDescMention(val, cursor, queryProp, atStartProp, dropProp) {
        const before = val.substring(0, cursor);
        const atIdx = before.lastIndexOf('@');
        if (atIdx !== -1) {
            const fragment = before.substring(atIdx + 1);
            if (!/[\s]/.test(fragment)) {
                this[queryProp] = fragment;
                this[atStartProp] = atIdx;
                this[dropProp] = true;
                return;
            }
        }
        this[dropProp] = false;
        this[queryProp] = '';
    }

    _applyDescMention(id, label, queryProp, atStartProp, dropProp, idsProp, taSelector, stateProp, statePropKey) {
        const val = statePropKey ? this[stateProp][statePropKey] : this[stateProp];
        const before = val.substring(0, this[atStartProp]);
        const after  = val.substring(this[atStartProp] + 1 + (this[queryProp] || '').length);
        const newVal = before + '@' + label + ' ' + after;
        if (statePropKey) {
            this[stateProp] = { ...this[stateProp], [statePropKey]: newVal };
        } else {
            this[stateProp] = { ...this[stateProp], Description: newVal };
        }
        if (!this[idsProp].includes(id)) this[idsProp] = [...this[idsProp], id];
        this[dropProp] = false;
        this[queryProp] = '';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const ta = this.template.querySelector(taSelector);
            if (ta) {
                ta.value = newVal;
                const nc = (before + '@' + label + ' ').length;
                ta.setSelectionRange(nc, nc);
                ta.focus();
            }
        }, 0);
    }

    // Edit Task description
    handleEditDescInput(event) {
        const val = event.target.value;
        this.editTask = { ...this.editTask, Description: val };
        this._detectDescMention(val, event.target.selectionStart,
            '_editDescMentionQuery', '_editDescMentionAtStart', 'showEditDescDropdown');
    }
    handleEditDescMentionSelect(event) {
        this._applyDescMention(
            event.currentTarget.dataset.id, event.currentTarget.dataset.label,
            '_editDescMentionQuery', '_editDescMentionAtStart', 'showEditDescDropdown',
            '_editDescMentionedIds', '.edit-desc-textarea', 'editTask', 'Description');
    }

    // New Task description
    handleNewDescInput(event) {
        const val = event.target.value;
        this.newTask = { ...this.newTask, Description: val };
        this._detectDescMention(val, event.target.selectionStart,
            '_newDescMentionQuery', '_newDescMentionAtStart', 'showNewDescDropdown');
    }
    handleNewDescMentionSelect(event) {
        this._applyDescMention(
            event.currentTarget.dataset.id, event.currentTarget.dataset.label,
            '_newDescMentionQuery', '_newDescMentionAtStart', 'showNewDescDropdown',
            '_newDescMentionedIds', '.new-desc-textarea', 'newTask', 'Description');
    }

    // Template description
    handleTmplDescInput(event) {
        const val = event.target.value;
        this.recurringTemplateForm = { ...this.recurringTemplateForm, Description__c: val };
        this._detectDescMention(val, event.target.selectionStart,
            '_tmplDescMentionQuery', '_tmplDescMentionAtStart', 'showTmplDescDropdown');
    }
    handleTmplDescMentionSelect(event) {
        this._applyDescMention(
            event.currentTarget.dataset.id, event.currentTarget.dataset.label,
            '_tmplDescMentionQuery', '_tmplDescMentionAtStart', 'showTmplDescDropdown',
            '_tmplDescMentionedIds', '.tmpl-desc-textarea', 'recurringTemplateForm', 'Description__c');
    }

    handleSaveEdit() {
        if (!this.editTask.Subject) {
            this.showError('Subject is required', null);
            return;
        }
        const taskId = this.editTask.Id;
        const editAssignMo   = (this.editAssignMonth || '1').padStart(2, '0');
        const editAssignDate = (this.editAssignOpen && this.editAssignYear)
            ? `${this.editAssignYear}-${editAssignMo}-01`
            : null;
        updateTask({
            taskId,
            subject:       this.editTask.Subject,
            projectId:     this.editProjectIds[0]        || null,
            kanbanStatus:  this.editTask.Kanban_Status__c,
            dueDate:       this.editTask.ActivityDate    || null,
            description:   this.editTask.Description,
            priority:      this.editTask.Priority,
            smartGoalIds:  this.editSmartGoalIds,
            timeSpent:     this.editTask.timeSpent !== '' && this.editTask.timeSpent != null ? this.editTask.timeSpent : null,
            assignedToId:  this.editTask.assignedToId    || null,
            assignToMonth: editAssignDate
        })
        .then(() => saveTaskRelations({ taskId, relatedTaskIds: this.editRelatedTaskIds }))
        .then(() => saveTaskProjects({ taskId, projectIds: this.editProjectIds }))
        .then(() => saveTaskTags({ taskId, tagIds: this.editTaskTagChips.map(t => t.id) }))
        .then(() => {
            if (this._editDescMentionedIds.length > 0) {
                return saveMentions({ taskId, userIds: this._editDescMentionedIds });
            }
        })
        .then(() => {
            this.showEditModal  = false;
            this.editAssignOpen = false;
            this._editTaskId = null;
            this.newCommentText = '';
            this.showMentionDropdown = false;
            this._mentionedUserIds = [];
            this._editDescMentionedIds = [];
            this.showEditDescDropdown = false;
            this.editSmartGoalIds = [];
            this.editSmartGoalSearch = '';
            this.showEditSmartGoalDropdown = false;
            this.editRelatedTaskIds = [];
            this.editRelatedTaskSearch = '';
            this.showEditRelatedDropdown = false;
            this.editProjectIds = [];
            this.editProjectSearch = '';
            this.showEditProjectDropdown = false;
            this.editTaskTagChips = [];
            this.editTaskTagSearch = '';
            this.showEditTaskTagDropdown = false;
            this.editTaskTagOptions = [];
            return refreshApex(this._wiredTasksResult);
        })
        .catch(err => this.showError('Failed to update task', err));
    }

    // ─── Comments ─────────────────────────────────────────────────────────────
    handleCommentInput(event) {
        const val = event.target.value;
        this.newCommentText = val;
        const cursor = event.target.selectionStart;
        const beforeCursor = val.substring(0, cursor);
        const atIdx = beforeCursor.lastIndexOf('@');
        if (atIdx !== -1) {
            const fragment = beforeCursor.substring(atIdx + 1);
            if (!/[\s]/.test(fragment)) {
                this._mentionQuery = fragment;
                this._mentionAtStart = atIdx;
                this.showMentionDropdown = true;
                return;
            }
        }
        this.showMentionDropdown = false;
        this._mentionQuery = '';
    }

    handleMentionSelect(event) {
        const id    = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        const val   = this.newCommentText;
        const before = val.substring(0, this._mentionAtStart);
        const after  = val.substring(this._mentionAtStart + 1 + this._mentionQuery.length);
        const newVal = before + '@' + label + ' ' + after;
        this.newCommentText = newVal;
        if (!this._mentionedUserIds.includes(id)) {
            this._mentionedUserIds = [...this._mentionedUserIds, id];
        }
        this.showMentionDropdown = false;
        this._mentionQuery = '';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const ta = this.template.querySelector('.mention-textarea');
            if (ta) {
                ta.value = newVal;
                const newCursor = (before + '@' + label + ' ').length;
                ta.setSelectionRange(newCursor, newCursor);
                ta.focus();
            }
        }, 0);
    }

    handleAddComment() {
        if (!this.newCommentText || !this.newCommentText.trim()) return;
        addComment({
            taskId:           this._editTaskId,
            commentText:      this.newCommentText.trim(),
            mentionedUserIds: this._mentionedUserIds
        })
        .then(() => {
            this.newCommentText = '';
            this._mentionedUserIds = [];
            this.showMentionDropdown = false;
            const ta = this.template.querySelector('.mention-textarea');
            if (ta) ta.value = '';
            return refreshApex(this._wiredCommentsResult);
        })
        .catch(err => this.showError('Failed to add comment', err));
    }

    handleDeleteComment(event) {
        const commentId = event.currentTarget.dataset.id;
        deleteComment({ commentId })
            .then(() => refreshApex(this._wiredCommentsResult))
            .catch(err => this.showError('Failed to delete comment', err));
    }

    // ─── File Upload ──────────────────────────────────────────────────────────
    handleUploadFinished() {
        syncTaskFilesToSharePoint({ taskId: this._editTaskId })
            .then(() => {
                this.showToast('Syncing to SharePoint', 'File is being moved to SharePoint. Reopen this task in a moment to see the link.', 'info');
            })
            .catch(err => {
                this.showError('SharePoint sync failed', err);
            });
    }

    // ─── Delete Confirmation ──────────────────────────────────────────────────
    handleDeleteClick(event) {
        this._pendingDeleteId = event.currentTarget.dataset.id;
        this.showDeleteConfirm = true;
    }

    handleDeleteConfirm() {
        this.showDeleteConfirm = false;
        deleteTask({ taskId: this._pendingDeleteId })
            .then(() => {
                this._pendingDeleteId = null;
                return refreshApex(this._wiredTasksResult);
            })
            .catch(err => this.showError('Failed to delete task', err));
    }

    handleDeleteCancel() {
        this.showDeleteConfirm = false;
        this._pendingDeleteId = null;
    }

    // ─── Recurring Task Templates ─────────────────────────────────────────────
    handleOpenRecurring() {
        getRecurringTemplates()
            .then(data => {
                this.recurringTemplates = data || [];
                this.showTemplateForm   = false;
                this.editingTemplateId  = null;
                this.showRecurringModal = true;
            })
            .catch(err => this.showError('Failed to load recurring templates', err));
    }

    handleCloseRecurring() {
        this.showRecurringModal          = false;
        this.showTemplateForm            = false;
        this.editingTemplateId           = null;
        this.templateProjectIds          = [];
        this.templateProjectSearch       = '';
        this.showTemplateProjectDropdown = false;
        this.templateTagChips            = [];
        this.templateTagSearch           = '';
        this.showTemplateTagDropdown     = false;
        this.templateTagOptions          = [];
        this._tmplDescMentionedIds       = [];
        this.showTmplDescDropdown        = false;
        this._tmplDescMentionQuery       = '';
    }

    handleCancelTemplateForm() {
        this.showTemplateForm            = false;
        this.editingTemplateId           = null;
        this.templateProjectIds          = [];
        this.templateProjectSearch       = '';
        this.showTemplateProjectDropdown = false;
        this.templateTagChips            = [];
        this.templateTagSearch           = '';
        this.showTemplateTagDropdown     = false;
        this.templateTagOptions          = [];
        this._tmplDescMentionedIds       = [];
        this.showTmplDescDropdown        = false;
        this._tmplDescMentionQuery       = '';
    }

    handleNewTemplate() {
        this.recurringTemplateForm = { Subject__c: '', Priority__c: 'Normal', Description__c: '', assignedToId: '', assignedLabel: '', Is_Active__c: true, frequency: 'Monthly', spawnDay: null };
        this.editingTemplateId        = null;
        this.templateSmartGoalIds     = [];
        this.templateSmartGoalSearch  = '';
        this.templateProjectIds       = [];
        this.templateProjectSearch    = '';
        this.showTemplateProjectDropdown = false;
        this.templateTagChips         = [];
        this.templateTagSearch        = '';
        this.showTemplateTagDropdown  = false;
        this.templateTagOptions       = [];
        this._tmplDescMentionedIds    = [];
        this.showTmplDescDropdown     = false;
        this._tmplDescMentionQuery    = '';
        this.showTemplateForm         = true;
    }

    handleEditTemplate(event) {
        const id = event.currentTarget.dataset.id;
        const tmpl = this.recurringTemplates.find(t => t.Id === id);
        if (!tmpl) return;
        const assignedUser = this.activeUsers && this.activeUsers.data
            ? this.activeUsers.data.find(u => u.Id === tmpl.Assigned_To__c)
            : null;
        this.recurringTemplateForm = {
            Subject__c:    tmpl.Subject__c    || '',
            Priority__c:   tmpl.Priority__c   || 'Normal',
            Description__c: tmpl.Description__c || '',
            assignedToId:  tmpl.Assigned_To__c || '',
            assignedLabel: assignedUser ? assignedUser.Name : '',
            Is_Active__c:  tmpl.Is_Active__c !== false,
            frequency:     tmpl.Frequency__c  || 'Monthly',
            spawnDay:      tmpl.Spawn_Day__c != null ? String(parseInt(tmpl.Spawn_Day__c, 10)) : null
        };
        this.editingTemplateId        = id;
        this.templateSmartGoalIds     = [];
        this.templateSmartGoalSearch  = '';
        this.templateProjectIds       = [];
        this.templateProjectSearch    = '';
        this.showTemplateProjectDropdown = false;
        this.templateTagChips         = [];
        this.templateTagSearch        = '';
        this.showTemplateTagDropdown  = false;
        this.templateTagOptions       = [];
        this._tmplDescMentionedIds    = [];
        this.showTmplDescDropdown     = false;
        this._tmplDescMentionQuery    = '';
        this.showTemplateForm         = true;
        this.loadTemplateSmartGoals();
        this.loadTemplateProjects();
        this.loadTemplateTags();
    }

    handleTemplateFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const updates = { [field]: event.detail.value };
        if (field === 'frequency') updates.spawnDay = null;
        this.recurringTemplateForm = { ...this.recurringTemplateForm, ...updates };
    }

    handleTemplateActiveChange(event) {
        this.recurringTemplateForm = { ...this.recurringTemplateForm, Is_Active__c: event.detail.checked };
    }

    handleTemplateAssignedSearch(event) {
        this.recurringTemplateForm = { ...this.recurringTemplateForm, assignedLabel: event.detail.value };
    }

    handleTemplateAssignedSelect(event) {
        const id    = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        this.recurringTemplateForm = { ...this.recurringTemplateForm, assignedToId: id, assignedLabel: label };
    }

    get filteredTemplateUserOptions() {
        const search = (this.recurringTemplateForm.assignedLabel || '').toLowerCase().trim();
        if (!search) return this.userOptions;
        return this.userOptions.filter(u => u.label.toLowerCase().includes(search));
    }

    // ─── Smart Goal multi-select (Recurring Template) ────────────────────────
    handleTemplateSmartGoalSearch(event) {
        this.templateSmartGoalSearch = event.detail.value;
        this.showTemplateSmartGoalDropdown = true;
    }

    handleTemplateSmartGoalFocus() {
        this.showTemplateSmartGoalDropdown = true;
    }

    handleTemplateSmartGoalBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showTemplateSmartGoalDropdown = false; }, 200);
    }

    handleTemplateSmartGoalSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (!this.templateSmartGoalIds.includes(id)) {
            this.templateSmartGoalIds = [...this.templateSmartGoalIds, id];
        }
        this.templateSmartGoalSearch = '';
        this.showTemplateSmartGoalDropdown = false;
    }

    handleTemplateSmartGoalRemove(event) {
        const id = event.currentTarget.dataset.id;
        this.templateSmartGoalIds = this.templateSmartGoalIds.filter(v => v !== id);
    }

    handleSaveTemplate() {
        if (!this.recurringTemplateForm.Subject__c) {
            this.showError('Subject is required', null);
            return;
        }
        let savedTemplateId;
        saveRecurringTemplate({
            templateId:   this.editingTemplateId || null,
            subject:      this.recurringTemplateForm.Subject__c,
            projectId:    this.templateProjectIds[0]              || null,
            priority:     this.recurringTemplateForm.Priority__c  || 'Normal',
            description:  this.recurringTemplateForm.Description__c,
            assignedToId: this.recurringTemplateForm.assignedToId || null,
            isActive:     this.recurringTemplateForm.Is_Active__c,
            smartGoalIds: this.templateSmartGoalIds,
            frequency:    this.recurringTemplateForm.frequency || 'Monthly',
            spawnDay:     this.recurringTemplateForm.spawnDay != null && this.recurringTemplateForm.spawnDay !== ''
                              ? parseInt(this.recurringTemplateForm.spawnDay, 10) : null
        })
        .then(result => {
            savedTemplateId = result.Id;
            return saveTemplateProjects({ templateId: savedTemplateId, projectIds: this.templateProjectIds });
        })
        .then(() => saveTemplateTags({ templateId: savedTemplateId, tagIds: this.templateTagChips.map(t => t.id) }))
        .then(() => getRecurringTemplates())
        .then(data => {
            this.recurringTemplates       = data || [];
            this.showTemplateForm         = false;
            this.editingTemplateId        = null;
            this.templateSmartGoalIds     = [];
            this.templateSmartGoalSearch  = '';
            this.templateProjectIds       = [];
            this.templateProjectSearch    = '';
            this.showTemplateProjectDropdown = false;
            this.templateTagChips         = [];
            this.templateTagSearch        = '';
            this.showTemplateTagDropdown  = false;
            this.templateTagOptions       = [];
        })
        .catch(err => this.showError('Failed to save template', err));
    }

    handleToggleActive(event) {
        const id       = event.currentTarget.dataset.id;
        const isActive = event.detail.checked;
        toggleRecurringTemplate({ templateId: id, isActive })
            .then(() => getRecurringTemplates())
            .then(data => { this.recurringTemplates = data || []; })
            .catch(err => this.showError('Failed to update template', err));
    }

    handleDeleteTemplate(event) {
        const id = event.currentTarget.dataset.id;
        deleteRecurringTemplate({ templateId: id })
            .then(() => getRecurringTemplates())
            .then(data => { this.recurringTemplates = data || []; })
            .catch(err => this.showError('Failed to delete template', err));
    }

    handleRunRecurringNow() {
        triggerRecurringSpawn()
            .then(() => {
                this.showToast('Recurring Tasks Spawned', 'Tasks from active templates have been added to Queue for this month.', 'success');
                return refreshApex(this._wiredTasksResult);
            })
            .catch(err => this.showError('Spawn failed', err));
    }

    // ─── Export ───────────────────────────────────────────────────────────────
    _defaultExportColumns() {
        if (this._exportColumns.length) {
            return this._exportColumns.map(c => ({ ...c, defaultOn: true }));
        }
        return [
            { Column_Header__c: 'Task ID',         Field_API_Name__c: 'Task_Number__c',   defaultOn: true  },
            { Column_Header__c: 'Title',            Field_API_Name__c: 'Subject',          defaultOn: true  },
            { Column_Header__c: 'Link',             Field_API_Name__c: 'Record_Link',      defaultOn: true  },
            { Column_Header__c: 'Status',           Field_API_Name__c: 'Kanban_Status__c', defaultOn: true  },
            { Column_Header__c: 'Priority',         Field_API_Name__c: 'Priority',         defaultOn: false },
            { Column_Header__c: 'Project',          Field_API_Name__c: 'Project_Name',     defaultOn: true  },
            { Column_Header__c: 'Due Date',          Field_API_Name__c: 'ActivityDate',       defaultOn: true  },
            { Column_Header__c: 'Assigned Month',   Field_API_Name__c: 'Assign_To_Month__c', defaultOn: false },
            { Column_Header__c: 'Created Date',     Field_API_Name__c: 'CreatedDate',        defaultOn: false },
            { Column_Header__c: 'Assigned To',      Field_API_Name__c: 'Assigned_To',      defaultOn: false },
            { Column_Header__c: 'Time Spent (hrs)', Field_API_Name__c: 'Time_Spent__c',    defaultOn: false },
            { Column_Header__c: 'Description',      Field_API_Name__c: 'Description',      defaultOn: false },
            { Column_Header__c: 'Smart Goal',       Field_API_Name__c: 'Smart_Goal_Name',  defaultOn: true  }
        ];
    }

    _initFieldSelection() {
        if (this.exportFieldSelection.length) return;
        this.exportFieldSelection = this._defaultExportColumns().map(c => ({
            key:     c.Field_API_Name__c,
            label:   c.Column_Header__c,
            enabled: c.defaultOn !== false
        }));
    }

    handleFieldSelectionToggle(event) {
        const key = event.currentTarget.dataset.key;
        this.exportFieldSelection = this.exportFieldSelection.map(f =>
            f.key === key ? { ...f, enabled: !f.enabled } : f
        );
        this._savePrefs();
    }

    _buildExportData() {
        const tasks = this.allTasks;
        if (!tasks.length) return null;

        const sorted = [...tasks].sort((a, b) => {
            const aGoal = (a.Smart_Goal__r && a.Smart_Goal__r.Initiative_Name__c) || 'ZZZZZZZZZZ';
            const bGoal = (b.Smart_Goal__r && b.Smart_Goal__r.Initiative_Name__c) || 'ZZZZZZZZZZ';
            return aGoal.localeCompare(bGoal) || (a.Subject || '').localeCompare(b.Subject || '');
        });

        const rawColumns = this._defaultExportColumns();

        // Apply user field selection
        const enabledKeys = this.exportFieldSelection.length
            ? new Set(this.exportFieldSelection.filter(f => f.enabled).map(f => f.key))
            : null;
        const filtered = enabledKeys ? rawColumns.filter(c => enabledKeys.has(c.Field_API_Name__c)) : rawColumns;

        // Keep Smart Goal at end if present
        const sgIdx = filtered.findIndex(c => c.Field_API_Name__c === 'Smart_Goal_Name');
        const columns = sgIdx > -1 && sgIdx < filtered.length - 1
            ? [...filtered.slice(0, sgIdx), ...filtered.slice(sgIdx + 1), filtered[sgIdx]]
            : filtered;

        const baseUrl = window.location.origin;
        const headers = columns.map(c => c.Column_Header__c);
        const rows = sorted.map(t =>
            columns.map(c => {
                switch (c.Field_API_Name__c) {
                    case 'Record_Link':        return `${baseUrl}/lightning/r/Task/${t.Id}/view`;
                    case 'Project_Name':       return t.Project__r ? t.Project__r.Name : '';
                    case 'Smart_Goal_Name':    return t.Smart_Goal__r ? (t.Smart_Goal__r.Initiative_Name__c || '') : '';
                    case 'Assigned_To':        return t.Owner ? (t.Owner.Name || '') : '';
                    case 'CreatedDate':        return t.CreatedDate ? t.CreatedDate.slice(0, 10) : '';
                    case 'Assign_To_Month__c': {
                        if (!t.Assign_To_Month__c) return '';
                        const [yr, mo] = t.Assign_To_Month__c.split('-');
                        return `${MONTH_NAMES[parseInt(mo, 10) - 1]} ${yr}`;
                    }
                    default:                   return t[c.Field_API_Name__c] != null ? String(t[c.Field_API_Name__c]) : '';
                }
            })
        );

        const [year, month] = (this.selectedMonth || '').split('-');
        let goalName = 'Tasks';
        if (this.selectedSmartGoalId && this.smartGoals && this.smartGoals.data) {
            const goal = this.smartGoals.data.find(g => g.Id === this.selectedSmartGoalId);
            if (goal) {
                goalName = (goal.Initiative_Name__c || goal.Name || 'Tasks')
                    .replace(/[^a-zA-Z0-9 ]/g, '')
                    .trim()
                    .replace(/\s+/g, '-');
            }
        }
        return { headers, rows, baseName: `${year}-${month}_${goalName}` };
    }

    _buildCsv() {
        const data = this._buildExportData();
        if (!data) return null;
        const { headers, rows, baseName } = data;
        const header = headers.map(h => `"${h}"`).join(',');
        const csvRows = rows.map(r => r.map(v => `"${String(v).replace(/"/g, '""')}"`).join(','));
        return { csv: [header, ...csvRows].join('\r\n'), filename: `${baseName}.csv` };
    }

    _buildXlsx() {
        const data = this._buildExportData();
        if (!data) return null;
        const { headers, rows, baseName } = data;
        const XL = window.XLSX;
        const ws = XL.utils.aoa_to_sheet([headers, ...rows]);
        const wb = XL.utils.book_new();
        XL.utils.book_append_sheet(wb, ws, 'Tasks');
        return { wb, filename: `${baseName}.xlsx` };
    }

    handleOpenExportModal() {
        if (!this.allTasks.length) {
            this.showToast('No tasks', 'There are no tasks to export for the selected month.', 'warning');
            return;
        }
        this.showExportModal = true;
    }

    handleExportFormatChange(event) {
        this.exportFormat = event.detail.value;
    }

    handleCancelExport() {
        this.showExportModal = false;
        this.exportFormat = 'xlsx';
    }

    handleConfirmExport() {
        if (this.exportFormat === 'xlsx') {
            if (!this._xlsxReady) {
                this.showToast('Not ready', 'Excel library is still loading. Please try again momentarily.', 'warning');
                return;
            }
            const built = this._buildXlsx();
            if (!built) return;
            window.XLSX.writeFile(built.wb, built.filename);
        } else {
            const built = this._buildCsv();
            if (!built) return;
            const link = document.createElement('a');
            link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(built.csv);
            link.setAttribute('download', built.filename);
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
        this.showExportModal = false;
        this.exportFormat = 'xlsx';
    }

    // ─── Reporting ────────────────────────────────────────────────────────────
    handleOpenReport() { this.showReportModal = true; }
    handleCloseReport() { this.showReportModal = false; }

    get queueBarStyle()      { return `width:${this.reportStats.queuePct}%`; }
    get inProgressBarStyle() { return `width:${this.reportStats.inProgressPct}%`; }
    get completeBarStyle()   { return `width:${this.reportStats.completePct}%`; }

    // ─── Bulk Operations ──────────────────────────────────────────────────────
    get hasSelection()       { return this.selectedTaskIds.length > 0; }
    get selectionCount()     { return this.selectedTaskIds.length; }
    get selectModeLabel()    { return this.selectMode ? 'Cancel Select' : 'Select'; }
    get bulkStatusOptions() {
        return [
            { label: 'Queue',       value: 'Queue' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Complete',    value: 'Complete' }
        ];
    }

    handleToggleSelectMode() {
        this.selectMode = !this.selectMode;
        this.selectedTaskIds = [];
    }

    handleCardClick(event) {
        if (!this.selectMode) return;
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        if (this.selectedTaskIds.includes(id)) {
            this.selectedTaskIds = this.selectedTaskIds.filter(i => i !== id);
        } else {
            this.selectedTaskIds = [...this.selectedTaskIds, id];
        }
    }

    handleSelectAll() {
        const allIds = this.allTasks.map(t => t.Id);
        this.selectedTaskIds = allIds;
    }

    handleClearSelection() { this.selectedTaskIds = []; }

    handleBulkStatusChange(event) {
        const newStatus = event.detail.value;
        if (!newStatus || !this.selectedTaskIds.length) return;
        this.bulkLoading = true;
        bulkUpdateStatus({ taskIds: this.selectedTaskIds, newStatus })
            .then(() => {
                this.showToast('Updated', `${this.selectedTaskIds.length} task(s) moved to ${newStatus}.`, 'success');
                this.selectedTaskIds = [];
                this.selectMode = false;
                return refreshApex(this._wiredTasksResult);
            })
            .catch(err => this.showError('Bulk update failed', err))
            .finally(() => { this.bulkLoading = false; });
    }

    get reportStats() {
        const tasks = this.allTasks;
        const total = tasks.length;
        const queue      = tasks.filter(t => t.Kanban_Status__c === 'Queue' || !t.Kanban_Status__c).length;
        const inProgress = tasks.filter(t => t.Kanban_Status__c === 'In Progress').length;
        const complete   = tasks.filter(t => t.Kanban_Status__c === 'Complete').length;

        // by project
        const projMap = {};
        tasks.forEach(t => {
            const name = t.Project__r ? t.Project__r.Name : '(No Project)';
            projMap[name] = (projMap[name] || 0) + 1;
        });
        const byProject = Object.keys(projMap)
            .sort((a, b) => projMap[b] - projMap[a])
            .map(name => {
                const pct = Math.round((projMap[name] / total) * 100);
                return { name, count: projMap[name], pct, barStyle: `width:${pct}%` };
            });

        // by priority
        const priMap = { High: 0, Normal: 0, Low: 0, '(None)': 0 };
        tasks.forEach(t => {
            const p = t.Priority || '(None)';
            priMap[p] = (priMap[p] || 0) + 1;
        });
        const byPriority = Object.keys(priMap)
            .filter(k => priMap[k] > 0)
            .map(name => {
                const pct = Math.round((priMap[name] / total) * 100);
                return { name, count: priMap[name], pct, barStyle: `width:${pct}%` };
            });

        return {
            total,
            queue,      queuePct:      total ? Math.round((queue      / total) * 100) : 0,
            inProgress, inProgressPct: total ? Math.round((inProgress / total) * 100) : 0,
            complete,   completePct:   total ? Math.round((complete   / total) * 100) : 0,
            byProject,
            byPriority
        };
    }

    // ─── Submit to Initiative Stage ───────────────────────────────────────────
    handleOpenSubmitModal() {
        if (!this.allTasks.length) {
            this.showToast('No tasks', 'There are no tasks to submit for the selected month.', 'warning');
            return;
        }
        if (!this.selectedSmartGoalId) {
            this.showToast('Select a Smart Goal', 'Please select a Smart Goal before submitting to an Initiative Stage.', 'warning');
            return;
        }
        this.submitLoading = true;
        this.showSubmitModal = true;
        this.selectedSubmitStageId = '';
        this.submitStageOptions = [];
        this._submitStagesRaw = [];

        getInitiativeStages({ smartGoalId: this.selectedSmartGoalId, selectedMonth: this.selectedMonth || '' })
            .then(stages => {
                this._submitStagesRaw = stages || [];
                this.submitStageOptions = (stages || []).map(s => ({
                    label: s.Status__c ? `${s.Name} — ${s.Status__c}` : s.Name,
                    value: s.Id
                }));
                this.selectedSubmitStageId = this._preselectStage(stages || []);
            })
            .catch(err => {
                this.showError('Could not load Initiative Stages', err);
                this.showSubmitModal = false;
            })
            .finally(() => { this.submitLoading = false; });
    }

    _preselectStage(stages) {
        if (!stages.length || !this.selectedMonth) return stages[0] ? stages[0].Id : '';
        const [year, month] = this.selectedMonth.split('-');
        const idx = parseInt(month, 10) - 1;
        const LONG  = ['January','February','March','April','May','June','July','August','September','October','November','December'];
        const SHORT = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        const variants = [LONG[idx], SHORT[idx]];
        if (idx === 8) variants.push('Sept');
        const match = stages.find(s => {
            const n = (s.Name || '').toLowerCase();
            return n.includes(year) && variants.some(v => n.includes(v.toLowerCase()));
        });
        return match ? match.Id : (stages[0] ? stages[0].Id : '');
    }

    handleSubmitStageChange(event) {
        this.selectedSubmitStageId = event.detail.value;
    }

    handleSubmitFormatChange(event) {
        this.submitFormat = event.detail.value;
    }

    handleCancelSubmit() {
        this.showSubmitModal = false;
        this.submitStageOptions = [];
        this.selectedSubmitStageId = '';
        this._submitStagesRaw = [];
        this.submitFormat = 'xlsx';
    }

    handleConfirmSubmit() {
        if (!this.selectedSubmitStageId) {
            this.showToast('No stage selected', 'Please select an Initiative Stage.', 'warning');
            return;
        }

        let fileBase64, filename;
        if (this.submitFormat === 'xlsx') {
            if (!this._xlsxReady) {
                this.showToast('Not ready', 'Excel library is still loading. Please try again momentarily.', 'warning');
                return;
            }
            const built = this._buildXlsx();
            if (!built) { this.showToast('No tasks', 'There are no tasks to submit.', 'warning'); return; }
            filename = built.filename;
            fileBase64 = window.XLSX.write(built.wb, { bookType: 'xlsx', type: 'base64' });
        } else {
            const built = this._buildCsv();
            if (!built) { this.showToast('No tasks', 'There are no tasks to submit.', 'warning'); return; }
            filename = built.filename;
            fileBase64 = btoa(unescape(encodeURIComponent(built.csv)));
        }

        this.submitLoading = true;
        attachCsvToInitiativeStage({ stageId: this.selectedSubmitStageId, csvBase64: fileBase64, filename })
            .then(() => {
                const stage = this._submitStagesRaw.find(s => s.Id === this.selectedSubmitStageId);
                const stageName = stage ? stage.Name : 'Initiative Stage';
                this.showToast('Submitted', `"${filename}" attached to ${stageName}.`, 'success');
                this.showSubmitModal = false;
                this.submitStageOptions = [];
                this.selectedSubmitStageId = '';
                this._submitStagesRaw = [];
                this.submitFormat = 'xlsx';
            })
            .catch(err => this.showError('Submit failed', err))
            .finally(() => { this.submitLoading = false; });
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(title, err) {
        const msg = err && err.body ? err.body.message : '';
        this.showToast(title, msg, 'error');
    }
}
