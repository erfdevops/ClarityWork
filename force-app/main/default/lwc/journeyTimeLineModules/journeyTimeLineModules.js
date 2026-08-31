import { LightningElement, track, wire } from 'lwc';
import getTimelineDataByModule from '@salesforce/apex/JourneyOverviewController.getTimelineDataByModule';
import getUserJourneys from '@salesforce/apex/JourneyOverviewController.getUserJourneys';
import EmptyStateImage from '@salesforce/resourceUrl/EmptyState';

export default class JourneyTimeLineModules extends LightningElement {
    @track expandedModules = [];
    @track journeyData = [];
    @track isLoading = true;
    @track error;
    @track journeyName = '';
    @track journeyLabel = 'My Journey';
    @track journeyOptions = [];
    @track selectedJourneyId = null;
    @track isEmpty = false;
    @track emptyStateMessage = '';
    emptyStateImageUrl = EmptyStateImage;

    @wire(getUserJourneys)
    wiredUserJourneys({ error, data }) {
        if (data) {
            this.journeyOptions = data.map(journey => ({
                label: journey.label,
                value: journey.value
            }));
            if (this.journeyOptions.length > 0 && !this.selectedJourneyId) {
                this.selectedJourneyId = this.journeyOptions[0].value;
            }
        } else if (error) {
            console.error('Error loading journeys:', error);
            this.error = error;
        }
    }

    @wire(getTimelineDataByModule, { journeyId: '$selectedJourneyId' })
    wiredTimelineData({ error, data }) {
        if (data && this.selectedJourneyId) {
            this.journeyName = data.journeyName || 'My Journey Timeline';
            this.journeyLabel = data.journeyLabel || 'My Journey';
            this.journeyData = data.weeks || [];
            this.isEmpty = data.isEmpty || false;
            this.emptyStateMessage = data.emptyStateMessage || '';

            // Auto-expand the first module on initial load
            if (this.journeyData.length > 0 && this.expandedModules.length === 0) {
                this.expandedModules = [this.journeyData[0].id];
            }

            this.isLoading = false;
            this.error = null;
        } else if (error) {
            console.error('Error loading timeline data by module:', error);
            this.error = error;
            this.isLoading = false;
            this.journeyData = [];
            this.isEmpty = false;
            this.emptyStateMessage = '';
        }
    }

    get processedJourneyData() {
        if (!this.journeyData || this.journeyData.length === 0) {
            return [];
        }
        return this.journeyData.map(module => ({
            ...module,
            isExpanded: this.expandedModules.includes(module.id),
            chevronIcon: this.expandedModules.includes(module.id) ? 'utility:chevrondown' : 'utility:chevronright',
            hasSubtitle: !!module.subtitle,
            items: module.items.map(item => ({
                ...item,
                completionIcon: item.isCompleted ? 'utility:check' : 'utility:radio_button',
                completionClass: item.isCompleted ? 'completed' : 'pending',
                pointsDisplay: item.points ? `+${item.points}.0 Points` : null
            }))
        }));
    }

    handleJourneyChange(event) {
        const selectedValue = event.target.value;
        if (!selectedValue) return;
        this.selectedJourneyId = selectedValue;
        this.isLoading = true;
        this.expandedModules = [];
        this.dispatchEvent(new CustomEvent('journeychange', {
            detail: {
                journeyId: this.selectedJourneyId,
                journeyName: this.journeyOptions.find(o => o.value === this.selectedJourneyId)?.label
            }
        }));
    }

    renderedCallback() {
        if (this.selectedJourneyId) {
            const selectElement = this.template.querySelector('.journey-selector');
            if (selectElement) {
                selectElement.value = this.selectedJourneyId;
            }
        }
    }

    handleWeekToggle(event) {
        const moduleId = event.currentTarget.dataset.weekId;
        const idx = this.expandedModules.indexOf(moduleId);
        if (idx === -1) {
            this.expandedModules = [...this.expandedModules, moduleId];
        } else {
            this.expandedModules = this.expandedModules.filter(id => id !== moduleId);
        }
    }

    handleTimelineItemClick(event) {
        event.stopPropagation();
        const dataset = event.currentTarget.dataset;
        const itemId = dataset.itemId;

        let timelineItemData = null;
        for (const module of this.journeyData) {
            const item = module.items.find(i => i.id === itemId);
            if (item) {
                timelineItemData = item;
                break;
            }
        }

        if (timelineItemData) {
            this.dispatchEvent(new CustomEvent('lessonnavigation', {
                detail: {
                    itemId,
                    lessonId: timelineItemData.lessonId,
                    courseId: timelineItemData.courseId || timelineItemData.moduleId,
                    moduleId: timelineItemData.moduleId,
                    enrollmentId: timelineItemData.enrollmentId,
                    moduleAssignmentId: timelineItemData.moduleAssignmentId,
                    timelineItem: timelineItemData,
                    lessonTitle: timelineItemData.title,
                    lessonSubtitle: timelineItemData.subtitle
                },
                bubbles: true,
                composed: true
            }));
        }
    }
}