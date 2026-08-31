import { LightningElement, api, track, wire } from 'lwc';
import getLessonAssignmentsData from '@salesforce/apex/MyProgramLessonsController.getLessonAssignmentsData';
import { refreshApex } from '@salesforce/apex';

export default class LessonListPanel extends LightningElement {
    @api lessonData = []; // Accept lesson data from parent component
    @track selectedAssignmentId; // Changed from selectedLessonId
    @track dynamicAssignments = []; // Changed from dynamicLessons
    @track isLoading = false;
    @track error;
    @track _courseId;
    @track _selectedLesson;
    @track _selectedCourse;
    @track _moduleAssignmentId;
    @track _moduleId;
    @track _enrollmentId;
    @track _lessonWeekAssignmentId;
    wiredAssignmentsResult; // Store the wired result for refresh capability

    // Wire method to get lesson assignments based on selected module
    @wire(getLessonAssignmentsData, { moduleId: '$moduleId' })
    wiredAssignments(result) {
        this.wiredAssignmentsResult = result; // Store the result for refresh capability
        const { error, data } = result;
        try {
            console.log('Wire method called with moduleId:', this.moduleId);
            if (data) {
                this.dynamicAssignments = data.assignments || [];
                this.isLoading = false;
                this.error = undefined;
                console.log('Lesson assignments loaded for module:', this.moduleId, this.dynamicAssignments);
                
                // Auto-select the assignment if it was passed from parent
                if (this.selectedLesson && this.selectedLesson.id) {
                    this.selectedAssignmentId = this.selectedLesson.id;
                    // Trigger selection event for the passed assignment
                    setTimeout(() => {
                        this.handleLessonClick({ currentTarget: { dataset: { id: this.selectedLesson.id } } });
                    }, 0);
                } else if (this._lessonWeekAssignmentId && this.dynamicAssignments.length > 0) {
                    // Auto-select based on the lesson week assignment ID passed from parent
                    const targetAssignment = this.dynamicAssignments.find(assignment => assignment.id === this._lessonWeekAssignmentId);
                    if (targetAssignment) {
                        this.selectedAssignmentId = targetAssignment.id;
                        setTimeout(() => {
                            this.handleLessonClick({ currentTarget: { dataset: { id: targetAssignment.id } } });
                        }, 0);
                    }
                } else if (this.dynamicAssignments.length > 0 && !this.selectedAssignmentId) {
                    // Select first assignment by default only if no specific assignment was passed
                    this.selectedAssignmentId = this.dynamicAssignments[0].id;
                    // Use setTimeout to ensure DOM is updated before triggering click
                    setTimeout(() => {
                        this.handleLessonClick({ currentTarget: { dataset: { id: this.dynamicAssignments[0].id } } });
                    }, 0);
                }
            } else if (error) {
                this.error = error;
                this.isLoading = false;
                this.dynamicAssignments = [];
                console.error('Error loading lesson assignments data for moduleId:', this.moduleId, 'Error:', error);
            } else {
                console.log('Wire method called but no data or error. ModuleId:', this.moduleId);
            }
        } catch (e) {
            console.error('Error in wiredAssignments:', e);
            this.error = e;
            this.isLoading = false;
            this.dynamicAssignments = [];
        }
    }

    // Get the module ID - prefer the direct moduleId, fallback to courseId
    get moduleId() {
        if (this._moduleId) {
            return this._moduleId;
        }
        
        if (!this.courseId) {
            return null;
        }
        
        if (typeof this.courseId === 'object') {
            return this.courseId.id || this.courseId.courseId || null;
        }
        return this.courseId;
    }

    // Custom setter for courseId to handle both objects and strings
    @api
    set courseId(value) {
        this._courseId = value;
        console.log('CourseId set:', value);
    }

    get courseId() {
        return this._courseId;
    }

    // Custom setter for selectedCourse
    @api
    set selectedCourse(value) {
        this._selectedCourse = value;
        console.log('lessonListPanel - selectedCourse set:', value);
        console.log('lessonListPanel - selectedCourse type:', typeof value);
        if (value && typeof value === 'object') {
            console.log('lessonListPanel - selectedCourse.title:', value.title);
            console.log('lessonListPanel - selectedCourse.id:', value.id);
        }
    }

    get selectedCourse() {
        return this._selectedCourse;
    }

    // Custom setter for selectedLesson
    @api
    set selectedLesson(value) {
        this._selectedLesson = value;
        if (value && value.id) {
            this.selectedAssignmentId = value.id; // Use selectedAssignmentId consistently
            console.log('Selected lesson assignment updated:', value.id);
        }
    }

    get selectedLesson() {
        return this._selectedLesson;
    }

    // Custom setter for moduleAssignmentId
    @api
    set moduleAssignmentId(value) {
        this._moduleAssignmentId = value;
        console.log('ModuleAssignmentId set:', value);
    }

    get moduleAssignmentId() {
        return this._moduleAssignmentId;
    }

    // Custom setter for moduleId
    @api
    set moduleId(value) {
        console.log('ModuleId setter called. Old value:', this._moduleId, 'New value:', value);
        this._moduleId = value;
        console.log('ModuleId set:', value);
    }

    get moduleId() {
        return this._moduleId;
    }

    // Custom setter for enrollmentId
    @api
    set enrollmentId(value) {
        this._enrollmentId = value;
        console.log('EnrollmentId set:', value);
    }

    // Custom setter for lessonWeekAssignmentId
    @api
    set lessonWeekAssignmentId(value) {
        this._lessonWeekAssignmentId = value;
        console.log('LessonWeekAssignmentId set:', value);
    }

    get lessonWeekAssignmentId() {
        return this._lessonWeekAssignmentId;
    }

    get enrollmentId() {
        return this._enrollmentId;
    }

    connectedCallback() {
        // Set first lesson as selected by default if none is selected
        if (!this.selectedLesson && this.lessons.length > 0) {
            this.selectedAssignmentId = this.lessons[0].id;
        } else if (this.selectedLesson) {
            this.selectedAssignmentId = this.selectedLesson.id;
        }
    }

    get lessons() {
        // Priority order: 1) Dynamic assignments from Apex, 2) Lesson data from parent, 3) Local fallback data
        let assignments = [];
        
        if (this.dynamicAssignments && this.dynamicAssignments.length > 0) {
            assignments = this.dynamicAssignments;
            console.log('Using dynamic assignments:', assignments.length);
        } else if (this.lessonData.length > 0) {
            assignments = this.lessonData;
            console.log('Using parent lesson data:', assignments.length);
        } else {
            assignments = this.getLocalLessons();
            console.log('Using local fallback lessons:', assignments.length);
        }
        
        return assignments.map(assignment => ({
            ...assignment,
            selected: assignment.id === this.selectedAssignmentId,
            isLesson: assignment.type === 'Lesson',
            title: assignment.lessonName || assignment.name, // Use lessonName for display
            // Map assignment fields to expected lesson structure for compatibility
            id: assignment.id, // This is the lesson week assignment ID
            lessonId: assignment.lessonId, // This is the actual lesson ID
            name: assignment.lessonName,
            type: assignment.type,
            completed: assignment.completed,
            status: assignment.status
        }));
    }

    getLocalLessons() {
        // Fallback lesson data for Course 1
        return [
            {
                id: 'l1',
                title: 'Lesson 1: Assignment 1 Module 4',
                duration: '1:1',
                points: 10,
                quizzes: 4,
                files: 0,
                type: 'Lesson',
                statusCompleted: true
            },
            {
                id: 'l2',
                title: 'Lesson 1: Assignment 2 Module 4',
                duration: '2:10',
                points: 1450,
                quizzes: 3,
                files: 5,
                type: 'Lesson',
                statusStart: true
            },
            {
                id: 'l3',
                title: 'Lesson 3: Assignment 3 Module 4',
                duration: '4:30',
                points: 200,
                quizzes: 3,
                files: 10,
                type: 'Lesson',
                statusStart: true
            },
            {
                id: 'a1',
                title: 'Assignment 1: Assignment 1 Module 4',
                duration: '1:1',
                points: 10,
                quizzes: 0,
                files: 0,
                type: 'Assignment',
                statusContinue: true
            },
            {
                id: 'l4',
                title: 'Lesson 4: Assignment 2 Module 4',
                duration: '2:10',
                points: 1450,
                quizzes: 2,
                files: 5,
                type: 'Lesson',
                statusStart: true
            },
            {
                id: 'a2',
                title: 'Assignment 3: Assignment 3 Module 4',
                duration: '4:30',
                points: 200,
                quizzes: 1,
                files: 10,
                type: 'Assignment',
                statusStart: true
            }
        ];
    }

    get courseTitle() {
        try {
            // Use selectedCourse first if available
            const courseData = this.selectedCourse || this.courseId;
            
            if (!courseData) return '';
            
            console.log('courseTitle getter - courseData:', courseData);
            console.log('courseTitle getter - courseData type:', typeof courseData);
            
            // If courseData is an object (full course object), extract the course name
            if (typeof courseData === 'object') {
                // Priority order for getting the course name:
                // 1. title (from course object)
                // 2. moduleName (from dynamic course data)
                // 3. courseName (alternative property)
                if (courseData.title) {
                    console.log('Using course title:', courseData.title);
                    return courseData.title;
                } else if (courseData.moduleName) {
                    console.log('Using module name:', courseData.moduleName);
                    return courseData.moduleName;
                } else if (courseData.courseName) {
                    console.log('Using course name:', courseData.courseName);
                    return courseData.courseName;
                }
                
                // Fallback: construct name from moduleCode and title if available
                const moduleCode = courseData.moduleCode || courseData.courseId || '';
                const courseName = courseData.courseName || courseData.title || '';
                
                if (moduleCode && courseName) {
                    const displayName = `${moduleCode} - ${courseName}`;
                    console.log('Using constructed name:', displayName);
                    return displayName;
                }
                
                // Extract ID for fallback
                const courseIdString = courseData.id || courseData.courseId;
                if (courseIdString && typeof courseIdString === 'string') {
                    return `Module ${courseIdString}`;
                }
            }
            
            // Handle string courseData (fallback)
            if (typeof courseData === 'string') {
                // If it looks like an ID pattern, format it nicely
                if (courseData.startsWith('c')) {
                    return `Course ${courseData.replace('c', '')}`;
                }
                return `Module ${courseData}`;
            }
            
            return 'Course';
        } catch (error) {
            console.error('Error in courseTitle getter:', error);
            return 'Course';
        }
    }

    handleLessonClick(event) {
        // Defensive check for event and currentTarget
        if (!event || !event.currentTarget || !event.currentTarget.dataset) {
            console.error('Invalid event in handleLessonClick:', event);
            return;
        }
        
        const assignmentId = event.currentTarget.dataset.id;
        console.log('Lesson assignment clicked:', assignmentId);
        
        // Update selected assignment
        this.selectedAssignmentId = assignmentId;
        
        // Find the selected assignment object
        const selectedAssignment = this.dynamicAssignments.find(assignment => assignment.id === assignmentId);
        
        // Dispatch event to parent component with lesson week assignment
        const selectEvent = new CustomEvent('lessonselect', {
            detail: { 
                lessonWeekAssignment: selectedAssignment, // Pass the full assignment object
                lessonWeekAssignmentId: assignmentId, // Pass the assignment ID
                courseId: this.courseId
            },
            bubbles: true
        });
        this.dispatchEvent(selectEvent);
    }

    handleMouseEnter(event) {
        // Add hover effect
        if (!event || !event.currentTarget || !event.currentTarget.dataset) {
            return;
        }
        
        const assignmentId = event.currentTarget.dataset.id;
        if (assignmentId !== this.selectedAssignmentId) {
            event.currentTarget.style.borderColor = '#004e14';
            event.currentTarget.style.backgroundColor = '#e8f5e9';
        }
    }

    handleMouseLeave(event) {
        // Remove hover effect if not selected
        if (!event || !event.currentTarget || !event.currentTarget.dataset) {
            return;
        }
        
        const assignmentId = event.currentTarget.dataset.id;
        if (assignmentId !== this.selectedAssignmentId) {
            event.currentTarget.style.borderColor = '#e6e6e6';
            event.currentTarget.style.backgroundColor = '#fff';
        }
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    // API method to update selected lesson from parent
    @api
    updateSelectedLesson(lessonId) {
        this.selectedLessonId = lessonId;
    }

    // API method to refresh lesson data from Apex
    @api
    async refresh() {
        try {
            console.log('Refreshing lesson assignments for module:', this.moduleId);
            
            // Trigger the refresh - this will update the list in the background
            await refreshApex(this.wiredAssignmentsResult);
            console.log('Lesson assignments refreshed successfully');
            
        } catch (error) {
            console.error('Error refreshing lesson assignments:', error);
            // Don't throw - allow the app to continue since we already updated the badge
        }
    }

    // API method to get the updated lesson data by ID
    @api
    getUpdatedLesson(lessonId) {
        const updatedLesson = this.dynamicAssignments.find(assignment => assignment.id === lessonId);
        console.log('Getting updated lesson:', lessonId, 'Result:', updatedLesson);
        return updatedLesson;
    }
}