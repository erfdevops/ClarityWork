import { LightningElement, track, wire, api } from 'lwc';
import getCoursesData from '@salesforce/apex/MyProgramCoursesController.getCoursesData';
import getCoursesDataByJourney from '@salesforce/apex/MyProgramCoursesController.getCoursesDataByJourney';
import getUserJourneys from '@salesforce/apex/MyProgramCoursesController.getUserJourneys';
import isCourseDetailsVisible from '@salesforce/apex/CommunityVisibilityHelper.isCourseDetailsVisible';
import EmptyStateImage from '@salesforce/resourceUrl/EmptyState';

export default class MyProgramCourses extends LightningElement {
    @api
    set selectedJourneyId(value) {
        if (value && value !== this.selectedJourneyId) {
            this.selectedJourneyId = value;
            this.isLoading = true;
            this.courses = [];
        }
    }
    get selectedJourneyId() {
        return this._selectedJourneyId;
    }
    _selectedJourneyId = null;
    @track courses = [];
    @track isLoading = true;
    @track error;
    @track journeyOptions = [];
    @track selectedJourneyId = null;
    @track isEmpty = false;
    @track emptyStateMessage = '';
    @track showCourseDetails = true; // Controls Duration and Points visibility
    emptyStateImageUrl = EmptyStateImage;
    
    // Private property to store preselected module
    _preselectedModule = null;

    // Lifecycle hook to initialize visibility settings
    connectedCallback() {
        console.log('MyProgramCourses connectedCallback - loading visibility settings');
        // Add a small delay to ensure Apex is ready
        setTimeout(() => {
            this.loadVisibilitySettings();
        }, 100);
    }

    // Method to load visibility settings from Apex
    async loadVisibilitySettings() {
        try {
            console.log('Calling isCourseDetailsVisible Apex method...');
            const result = await isCourseDetailsVisible();
            console.log('Course Details visibility result:', result);
            this.showCourseDetails = result;
        } catch (error) {
            console.error('Error calling isCourseDetailsVisible:', error);
            console.log('Will continue with default showCourseDetails = true');
            // Don't throw - continue with default value
            this.showCourseDetails = true;
        }
    }

    // API property with setter to handle changes
    @api 
    get preselectedModule() {
        return this._preselectedModule;
    }
    
    set preselectedModule(value) {
        this._preselectedModule = value;
        // Process the preselected module when it changes
        if (value && this.courses.length > 0) {
            this.handlePreselectedModule();
        }
    }

    // Wire to get user journeys for dropdown
    @wire(getUserJourneys)
    wiredUserJourneys({ error, data }) {
        if (data) {
            // Select first journey by default if none selected
            if (!this.selectedJourneyId && data.length > 0) {
                this.selectedJourneyId = data[0].value;
            }
            
            // Map journeys and mark selected one
            this.journeyOptions = data.map(journey => ({
                label: journey.label,
                value: journey.value,
                selected: journey.value === this.selectedJourneyId
            }));
        } else if (error) {
            console.error('Error loading journeys:', error);
            this.error = error;
        }
    }

    // Wire to get courses data for selected journey
    @wire(getCoursesDataByJourney, { journeyId: '$selectedJourneyId' })
    wiredCourses({ error, data }) {
        if (data && this.selectedJourneyId) {
            this.courses = data.courses || [];
            this.isEmpty = data.isEmpty || false;
            this.emptyStateMessage = data.emptyStateMessage || '';
            this.isLoading = false;
            this.error = undefined;
            // Check for preselected module and auto-select matching course
            this.handlePreselectedModule();
            // Dispatch initial course selection when component loads (if no preselection)
            if (!this._preselectedModule) {
                const selectedCourse = this.courses.find(course => course.selected);
                if (selectedCourse) {
                    this.dispatchCourseChangeEvent(selectedCourse);
                }
            }
        } else if (error) {
            this.error = error;
            this.isLoading = false;
            this.courses = [];
            this.isEmpty = false;
            this.emptyStateMessage = '';
            console.error('Error loading courses data:', error);
        }
    }

    // Handle preselected module from journey overview
    handlePreselectedModule() {
        if (this._preselectedModule && this.courses.length > 0) {
            console.log('Handling preselected module:', this._preselectedModule);
            console.log('Available courses:', this.courses.map(c => ({id: c.id, title: c.title})));
            
            // Find the course that matches the preselected module ID
            let targetCourse = this.courses.find(course => {
                // The course ID in myProgramCourses should match the module ID from journey overview
                console.log('Comparing course ID:', course.id, 'with preselected module ID:', this._preselectedModule.moduleId);
                return course.id === this._preselectedModule.moduleId;
            });
            
            // If we found a matching course, select it
            if (targetCourse) {
                console.log('Found matching course:', targetCourse.title);
                this.courses = this.courses.map(course => ({
                    ...course,
                    selected: course.id === targetCourse.id
                }));
                
                // Dispatch the course selection event
                this.dispatchCourseChangeEvent(targetCourse);
                console.log('Auto-selected course for preselected module:', targetCourse.title);
            } else {
                console.log('No matching course found for module ID:', this._preselectedModule.moduleId);
                // If no specific match, select the first course as fallback
                if (this.courses.length > 0) {
                    this.courses = this.courses.map((course, index) => ({
                        ...course,
                        selected: index === 0
                    }));
                    this.dispatchCourseChangeEvent(this.courses[0]);
                    console.log('Fallback: Selected first course:', this.courses[0].title);
                }
            }
        }
    }

    handleJourneyChange(event) {
        const selectedValue = event.target.value;
        
        // Do not trigger search if "Select Journey" (empty value) is selected
        if (!selectedValue) {
            return;
        }
        
        this.selectedJourneyId = selectedValue;
        this.isLoading = true;
        
        // Update selected property for dropdown display
        this.journeyOptions = this.journeyOptions.map(option => ({
            ...option,
            selected: option.value === selectedValue
        }));
        
        // Clear course selection when changing journey
        this.courses = [];
    }

    handleSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.courses = this.courses.map(course => ({
            ...course,
            selected: course.id === selectedId
        }));
        
        // Dispatch course selection event to parent components
        const selectedCourse = this.courses.find(c => c.id === selectedId);
        this.dispatchCourseChangeEvent(selectedCourse);
    }

    dispatchCourseChangeEvent(course) {
        this.dispatchEvent(new CustomEvent('coursechange', { 
            detail: {
                courseId: course.id,
                course: course
            }
        }));
    }
}