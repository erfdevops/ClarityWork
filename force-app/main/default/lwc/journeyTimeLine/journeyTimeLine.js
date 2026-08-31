import { LightningElement, track, wire } from 'lwc';
import getTimelineData from '@salesforce/apex/JourneyOverviewController.getTimelineData';
import getTimelineDataByJourney from '@salesforce/apex/JourneyOverviewController.getTimelineDataByJourney';
import getUserJourneys from '@salesforce/apex/JourneyOverviewController.getUserJourneys';
import getJourneyDataById from '@salesforce/apex/JourneyOverviewController.getJourneyDataById';
import isWeekCountVisible from '@salesforce/apex/CommunityVisibilityHelper.isWeekCountVisible';
import EmptyStateImage from '@salesforce/resourceUrl/EmptyState';

export default class JourneyTimeLine extends LightningElement {
    @track expandedWeeks = ['week1']; // Week 1 is expanded by default
    @track journeyData = [];
    @track isLoading = true;
    @track error;
    @track journeyName = '';
    @track journeyLabel = 'My Journey'; // Default label from metadata
    @track weekLabel = 'Week'; // Default label from metadata
    @track journeyOptions = [];
    @track selectedJourneyId = null;
    @track isEmpty = false;
    @track emptyStateMessage = '';
    @track showWeekCount = true; // Controls Week Count visibility
    emptyStateImageUrl = EmptyStateImage;

    // Lifecycle hook to initialize visibility settings
    connectedCallback() {
        console.log('JourneyTimeLine connectedCallback - loading visibility settings');
        this.loadWeekCountVisibility();
    }

    // Imperative method to load Week Count visibility
    async loadWeekCountVisibility() {
        try {
            console.log('Calling isWeekCountVisible...');
            const result = await isWeekCountVisible();
            console.log('Week Count visibility result:', result);
            this.showWeekCount = result;
        } catch (error) {
            console.error('Error calling isWeekCountVisible:', error);
            console.log('Will continue with default showWeekCount = true');
            this.showWeekCount = true;
        }
    }

    // Wire method to get user journeys for dropdown
    @wire(getUserJourneys)
    wiredUserJourneys({ error, data }) {
        if (data) {
            this.journeyOptions = data.map(journey => ({
                label: journey.label,
                value: journey.value
            }));
            
            // Select first journey by default
            if (this.journeyOptions.length > 0 && !this.selectedJourneyId) {
                this.selectedJourneyId = this.journeyOptions[0].value;
            }
        } else if (error) {
            console.error('Error loading journeys:', error);
            this.error = error;
        }
    }

    // Wire method to get timeline data for selected journey
    @wire(getTimelineDataByJourney, { journeyId: '$selectedJourneyId' })
    wiredTimelineData({ error, data }) {
        if (data && this.selectedJourneyId) {
            console.log('Timeline data received:', JSON.stringify(data, null, 2));
            this.journeyName = data.journeyName || 'My Journey Timeline';
            this.journeyLabel = data.journeyLabel || 'My Journey';
            this.weekLabel = data.weekLabel || 'Week';
            this.journeyData = data.weeks || [];
            this.isEmpty = data.isEmpty || false;
            this.emptyStateMessage = data.emptyStateMessage || '';
            
            // Debug: Log the first item to check if moduleId is present
            if (this.journeyData.length > 0 && this.journeyData[0].items && this.journeyData[0].items.length > 0) {
                console.log('Sample timeline item:', this.journeyData[0].items[0]);
                console.log('Sample item moduleId:', this.journeyData[0].items[0].moduleId);
                console.log('Sample item enrollmentId:', this.journeyData[0].items[0].enrollmentId);
                console.log('Sample item moduleAssignmentId:', this.journeyData[0].items[0].moduleAssignmentId);
            }
            
            // Set expanded state for weeks
            this.journeyData.forEach(week => {
                week.isExpanded = this.expandedWeeks.includes(week.id);
            });
            
            this.isLoading = false;
            this.error = null;
        } else if (error) {
            console.error('Error loading timeline data:', error);
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
        
        return this.journeyData.map(week => ({
            ...week,
            isExpanded: this.expandedWeeks.includes(week.id),
            chevronIcon: this.expandedWeeks.includes(week.id) ? 'utility:chevrondown' : 'utility:chevronright',
            hasSubtitle: !!week.subtitle,
            items: week.items.map(item => ({
                ...item,
                iconName: item.type === 'lesson' ? 'utility:education' : 'utility:assignment',
                completionIcon: item.isCompleted ? 'utility:check' : 'utility:radio_button',
                completionClass: item.isCompleted ? 'completed' : 'pending',
                pointsDisplay: item.points ? `+${item.points}.0 Points` : null,
                hasQuiz: item.quizCount && item.quizCount > 0
            }))
        }));
    }

    handleJourneyChange(event) {
        const selectedValue = event.target.value;
        
        // Do not trigger search if "Select Journey" (empty value) is selected
        if (!selectedValue) {
            return;
        }
        
        this.selectedJourneyId = selectedValue;
        this.isLoading = true;
        
        // Reset expanded weeks when changing journey
        this.expandedWeeks = ['week1'];
        
        // Dispatch event to notify parent components about journey change
        this.dispatchEvent(new CustomEvent('journeychange', {
            detail: {
                journeyId: this.selectedJourneyId,
                journeyName: this.journeyOptions.find(option => option.value === this.selectedJourneyId)?.label
            }
        }));
    }

    renderedCallback() {
        // Set the select value after rendering to ensure first journey is pre-selected
        if (this.selectedJourneyId) {
            const selectElement = this.template.querySelector('.journey-selector');
            if (selectElement) {
                selectElement.value = this.selectedJourneyId;
            }
        }
    }

    handleWeekToggle(event) {
        const weekId = event.currentTarget.dataset.weekId;
        const currentIndex = this.expandedWeeks.indexOf(weekId);
        
        if (currentIndex === -1) {
            // Add to expanded weeks
            this.expandedWeeks = [...this.expandedWeeks, weekId];
        } else {
            // Remove from expanded weeks
            this.expandedWeeks = this.expandedWeeks.filter(id => id !== weekId);
        }
    }

    // Handle timeline item click to navigate to lesson content
    handleTimelineItemClick(event) {
        event.stopPropagation(); // Prevent week toggle when clicking timeline items
        
        const dataset = event.currentTarget.dataset;
        const itemId = dataset.itemId;
        
        // Find the timeline item data for additional context
        let timelineItemData = null;
        for (const week of this.journeyData) {
            const item = week.items.find(item => item.id === itemId);
            if (item) {
                timelineItemData = item;
                break;
            }
        }
        
        if (timelineItemData) {
            console.log('Timeline item clicked:', timelineItemData.title, 'Lesson ID:', timelineItemData.lessonId);
            console.log('Timeline item full data:', timelineItemData);
            
            // Use data from the timeline item object instead of dataset to ensure we have all values
            const lessonId = timelineItemData.lessonId;
            const courseId = timelineItemData.courseId || timelineItemData.moduleId;
            const moduleId = timelineItemData.moduleId;
            const enrollmentId = timelineItemData.enrollmentId;
            const moduleAssignmentId = timelineItemData.moduleAssignmentId;
            
            console.log('Extracted values:', {
                itemId,
                lessonId,
                courseId,
                moduleId,
                enrollmentId,
                moduleAssignmentId
            });
            
            // Dispatch custom event to navigate to lesson content
            const lessonNavigationEvent = new CustomEvent('lessonnavigation', {
                detail: {
                    itemId,
                    lessonId,
                    courseId,
                    moduleId,
                    enrollmentId,
                    moduleAssignmentId,
                    timelineItem: timelineItemData,
                    lessonTitle: timelineItemData.title,
                    lessonSubtitle: timelineItemData.subtitle
                },
                bubbles: true
            });
            
            this.dispatchEvent(lessonNavigationEvent);
        }
    }
}