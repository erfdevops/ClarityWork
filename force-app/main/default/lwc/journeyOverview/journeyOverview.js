import { LightningElement, track, wire, api } from 'lwc';
import getJourneyData from '@salesforce/apex/JourneyOverviewController.getJourneyData';
import getJourneyDataById from '@salesforce/apex/JourneyOverviewController.getJourneyDataById';
import getUserJourneys from '@salesforce/apex/JourneyOverviewController.getUserJourneys';
import isPointsGainedVisible from '@salesforce/apex/CommunityVisibilityHelper.isPointsGainedVisible';
import isBadgesAchievedVisible from '@salesforce/apex/CommunityVisibilityHelper.isBadgesAchievedVisible';
import isModulesInProgressVisible from '@salesforce/apex/CommunityVisibilityHelper.isModulesInProgressVisible';
import isModulesCompletedVisible from '@salesforce/apex/CommunityVisibilityHelper.isModulesCompletedVisible';
import { refreshApex } from '@salesforce/apex';

export default class JourneyOverview extends LightningElement {
    @api timelineJourneyId;
    
    @track selectedFilter = 'all';
    @track journeyData = {};
    @track isLoading = true;
    @track error;
    @track selectedJourneyId = null;
    @track showPointsGained = true;      // Controls Points Gained tile visibility
    @track showBadgesAchieved = true;    // Controls Badges Achieved tile visibility
    @track showModulesInProgress = true; // Controls Modules In Progress tile visibility
    @track showModulesCompleted = true;  // Controls Modules Completed tile visibility
    
    // Stats properties for template binding
    @track totalModules = 0;
    @track completedModules = 0;
    @track inProgressModules = 0;
    @track totalPoints = 0;
    @track earnedPoints = 0;
    @track badgesAchieved = 0;
    @track totalBadges = 0;
    @track totalLessonAssignments = 0;
    @track completedLessonAssignments = 0;
    @track progressPercentage = 0;

    // Lifecycle hook to initialize visibility settings
    connectedCallback() {
        console.log('JourneyOverview connectedCallback - loading visibility settings');
        this.isLoading = true;
        // Add a small delay to ensure Apex is ready
        setTimeout(() => {
            this.loadVisibilitySettings();
        }, 100);
    }

    // Method to load visibility settings from Apex
    async loadVisibilitySettings() {
        try {
            const [pointsResult, badgesResult, inProgressResult, completedResult] = await Promise.all([
                isPointsGainedVisible(),
                isBadgesAchievedVisible(),
                isModulesInProgressVisible(),
                isModulesCompletedVisible()
            ]);
            this.showPointsGained = pointsResult;
            this.showBadgesAchieved = badgesResult;
            this.showModulesInProgress = inProgressResult;
            this.showModulesCompleted = completedResult;
            console.log('Visibility settings loaded:', {
                showPointsGained: this.showPointsGained,
                showBadgesAchieved: this.showBadgesAchieved,
                showModulesInProgress: this.showModulesInProgress,
                showModulesCompleted: this.showModulesCompleted
            });
        } catch (error) {
            console.error('Error loading visibility settings:', error);
            this.showPointsGained = true;
            this.showBadgesAchieved = true;
            this.showModulesInProgress = true;
            this.showModulesCompleted = true;
        }
    }

    // Getter for dynamic tile width based on visible tiles
    get tileWidthClass() {
        const visibleCount = [
            this.showBadgesAchieved,
            this.showModulesInProgress,
            this.showModulesCompleted,
            this.showPointsGained
        ].filter(Boolean).length;
        const sizeMap = { 1: '1-of-1', 2: '1-of-2', 3: '1-of-3', 4: '1-of-4' };
        return `slds-col slds-size_${sizeMap[visibleCount] || '1-of-4'}`;
    }

    // Wire to get user journeys and set default
    @wire(getUserJourneys)
    wiredUserJourneys({ error, data }) {
        if (data && data.length > 0 && !this.selectedJourneyId) {
            this.selectedJourneyId = data[0].value;
        } else if (error) {
            console.error('Error loading journeys:', error);
        }
    }

    // Wire to get journey data
    wiredJourneyResult;
    
    @wire(getJourneyDataById, { journeyId: '$selectedJourneyId' })
    wiredJourney(result) {
        this.wiredJourneyResult = result;
        if (result.data && this.selectedJourneyId) {
            this.journeyData = result.data;
            console.log('Journey data received:', JSON.stringify(result.data, null, 2));
            this.handleDataSuccess(result.data);
        } else if (result.error) {
            this.handleDataError(result.error);
        }
    }

    // Method to handle journey change from timeline
    @api
    handleJourneyChange(journeyId) {
        this.selectedJourneyId = journeyId;
        this.isLoading = true;
    }

    // Process the journey data for UI display
    processJourneyData(data) {
        if (data && data.modules) {
            // Update stats from Apex response
            if (data.stats) {
                this.updateStatsFromApex(data.stats);
            }
            
            // Convert modules to course data format for compatibility
            this.courseData = data.modules.map(module => ({
                id: module.id,
                courseName: module.moduleName || 'Module Name', // Display Module Name (Module_Name__c)
                moduleName: module.moduleCode || 'Module Code', // Display Module Code (Name field)
                nextModule: `Level ${module.moduleLevel || 'Next Level'}`,
                status: module.status || 'Upcoming',
                statusClass: module.statusClass || 'status-badge status-upcoming',
                filterCategory: this.getFilterCategory(module.status),
                badge: module.moduleBadge, // Use the rich text badge from module
                moduleData: module // Store full module data for reference
            }));
        }
    }

    // Update stats display with data from Apex
    updateStatsFromApex(stats) {
        this.totalModules = stats.totalModules || 0;
        this.completedModules = stats.completedModules || 0;
        this.inProgressModules = stats.inProgressModules || 0;
        this.totalPoints = stats.totalPoints || 0;
        this.earnedPoints = stats.earnedPoints || 0;
        this.badgesAchieved = stats.badgesAchieved || 0;
        this.totalBadges = stats.totalBadges || 0;
        this.totalLessonAssignments = stats.totalLessonAssignments || 0;
        this.completedLessonAssignments = stats.completedLessonAssignments || 0;
        this.progressPercentage = stats.progressPercentage || 0;
    }

    // Getter for progress bar style
    get progressBarStyle() {
        return `width: ${this.progressPercentage}%`;
    }

    // Map status to filter category
    getFilterCategory(status) {
        switch (status) {
            case 'Completed': return 'completed';
            case 'In Progress': return 'progress';
            case 'Not Started':
            case 'Upcoming':
            default: return 'upcoming';
        }
    }

    // Filter dropdown options
    categoryOptions = [
        { label: 'Filter by Category', value: 'all' },
        { label: 'All Modules', value: 'all' },
        { label: 'Not Started', value: 'upcoming' },
        { label: 'In Progress', value: 'progress' },
        { label: 'Completed', value: 'completed' }
    ];

    // Dynamic course data (will be populated from Apex)
    @track courseData = [];

    // Handle successful data load
    handleDataSuccess(data) {
        this.isLoading = false;
        this.error = null;
        console.log('Processing journey data:', data);
        this.processJourneyData(data);
        console.log('Processed course data:', this.courseData);
    }

    // Handle data load error
    handleDataError(error) {
        this.isLoading = false;
        this.error = error;
        console.error('Error loading journey data:', error);
    }

    // Check if we should show empty state
    get showEmptyState() {
        return !this.isLoading && !this.error && this.filteredCourseData.length === 0;
    }

    // Computed property for filtered course data
    get filteredCourseData() {
        let filtered = [];
        if (this.selectedFilter === 'all') {
            filtered = this.courseData;
        } else {
            filtered = this.courseData.filter(course => course.filterCategory === this.selectedFilter);
        }
        
        // Add isLast property to each item for separator display
        return filtered.map((course, index) => ({
            ...course,
            isLast: index === filtered.length - 1
        }));
    }

    // Handle filter change event
    handleFilterChange(event) {
        this.selectedFilter = event.target.value;
        console.log('Filter changed to:', this.selectedFilter);
    }

    // Handle module card click to navigate to Modules tab
    handleModuleClick(event) {
        const moduleId = event.currentTarget.dataset.moduleId;
        const moduleData = this.courseData.find(course => course.id === moduleId);
        if (moduleData) {
            console.log('Module clicked:', moduleData);
            // Dispatch custom event to navigate to Modules tab with preselected module and journeyId
            const navigationEvent = new CustomEvent('modulenavigation', {
                detail: {
                    moduleId: moduleId,
                    moduleData: moduleData.moduleData, // Pass the full module data
                    courseName: moduleData.courseName,
                    moduleName: moduleData.moduleName,
                    journeyId: this.timelineJourneyId
                },
                bubbles: true
            });
            this.dispatchEvent(navigationEvent);
        }
    }
}