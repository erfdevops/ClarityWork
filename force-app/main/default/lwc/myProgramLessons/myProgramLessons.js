import { LightningElement, api, track, wire } from 'lwc';
import getLessonAssignmentsData from '@salesforce/apex/MyProgramLessonsController.getLessonAssignmentsData';
import updateLessonWeekAssignmentStatus from '@salesforce/apex/MyProgramLessonsController.updateLessonWeekAssignmentStatus';
import isLessonsFilterVisible from '@salesforce/apex/CommunityVisibilityHelper.isLessonsFilterVisible';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import EmptyStateImage from '@salesforce/resourceUrl/EmptyState';

const LESSONS = {
    c1: [
        {
            id: 'l1',
            title: 'Lesson 1: Assignment 1 Module 4',
            duration: '1:1',
            points: 10,
            quizzes: 4,  // Updated to match actual quiz questions
            files: 0,
            type: 'Lesson',
            statusCompleted: true,
            quiz: {
                id: 'quiz-l1',
                questions: [
                    {
                        id: 'q1',
                        text: 'What is the Fourth Industrial Revolution?',
                        options: [
                            {
                                id: 'q1a',
                                text: 'A. It is a reorganization of cheap production and increased productivity',
                                isCorrect: true
                            },
                            {
                                id: 'q1b',
                                text: 'B. It is a time when customer expectations are driving the creation of new technologies',
                                isCorrect: false
                            },
                            {
                                id: 'q1c',
                                text: 'C. It is a revolution that is very difficult to manage, whether physical and understanding the customer experience',
                                isCorrect: false
                            },
                            {
                                id: 'q1d',
                                text: 'D. It is a plan to develop new technology that will eventually overtake risks',
                                isCorrect: false
                            }
                        ]
                    },
                    {
                        id: 'q2',
                        text: 'Which technology is NOT typically associated with Industry 4.0?',
                        options: [
                            {
                                id: 'q2a',
                                text: 'A. Artificial Intelligence',
                                isCorrect: false
                            },
                            {
                                id: 'q2b',
                                text: 'B. Internet of Things (IoT)',
                                isCorrect: false
                            },
                            {
                                id: 'q2c',
                                text: 'C. Steam Engine',
                                isCorrect: true
                            },
                            {
                                id: 'q2d',
                                text: 'D. Machine Learning',
                                isCorrect: false
                            }
                        ]
                    },
                    {
                        id: 'q3',
                        text: 'What are the key benefits of digital transformation in business?',
                        options: [
                            {
                                id: 'q3a',
                                text: 'A. Improved efficiency and customer experience',
                                isCorrect: true
                            },
                            {
                                id: 'q3b',
                                text: 'B. Higher operational costs',
                                isCorrect: false
                            },
                            {
                                id: 'q3c',
                                text: 'C. Reduced automation capabilities',
                                isCorrect: false
                            },
                            {
                                id: 'q3d',
                                text: 'D. Less data collection and analysis',
                                isCorrect: false
                            }
                        ]
                    },
                    {
                        id: 'q4',
                        text: 'Which of the following best describes "smart manufacturing"?',
                        options: [
                            {
                                id: 'q4a',
                                text: 'A. Traditional assembly line production',
                                isCorrect: false
                            },
                            {
                                id: 'q4b',
                                text: 'B. Manufacturing with basic automation',
                                isCorrect: false
                            },
                            {
                                id: 'q4c',
                                text: 'C. Interconnected systems using IoT, AI, and data analytics',
                                isCorrect: true
                            },
                            {
                                id: 'q4d',
                                text: 'D. Manual quality control processes',
                                isCorrect: false
                            }
                        ]
                    }
                ]
            }
        },
        {
            id: 'l2',
            title: 'Lesson 1: Assignment 2 Module 4',
            duration: '2:10',
            points: 1450,
            quizzes: 3,  // Updated to match actual quiz questions
            files: 5,
            type: 'Lesson',
            statusStart: true,
            quiz: {
                id: 'quiz-l2',
                questions: [
                    {
                        id: 'q1',
                        text: 'What is the Fourth Industrial Revolution?',
                        options: [
                            {
                                id: 'q1a',
                                text: 'A. It is a reorganization of cheap production and increased productivity',
                                isCorrect: true
                            },
                            {
                                id: 'q1b',
                                text: 'B. It is a time when customer expectations are driving the creation of new technologies',
                                isCorrect: false
                            },
                            {
                                id: 'q1c',
                                text: 'C. It is a revolution that is very difficult to manage, whether physical and understanding the customer experience',
                                isCorrect: false
                            },
                            {
                                id: 'q1d',
                                text: 'D. It is a plan to develop new technology that will eventually overtake risks',
                                isCorrect: false
                            }
                        ]
                    },
                    {
                        id: 'q2',
                        text: 'Which technology is NOT typically associated with Industry 4.0?',
                        options: [
                            {
                                id: 'q2a',
                                text: 'A. Artificial Intelligence',
                                isCorrect: false
                            },
                            {
                                id: 'q2b',
                                text: 'B. Internet of Things (IoT)',
                                isCorrect: false
                            },
                            {
                                id: 'q2c',
                                text: 'C. Steam Engine',
                                isCorrect: true
                            },
                            {
                                id: 'q2d',
                                text: 'D. Machine Learning',
                                isCorrect: false
                            }
                        ]
                    },
                    {
                        id: 'q3',
                        text: 'What is the primary goal of implementing IoT in manufacturing?',
                        options: [
                            {
                                id: 'q3a',
                                text: 'A. To increase manual labor requirements',
                                isCorrect: false
                            },
                            {
                                id: 'q3b',
                                text: 'B. To create connected systems for real-time monitoring',
                                isCorrect: true
                            },
                            {
                                id: 'q3c',
                                text: 'C. To reduce data collection',
                                isCorrect: false
                            },
                            {
                                id: 'q3d',
                                text: 'D. To eliminate all automation',
                                isCorrect: false
                            }
                        ]
                    }
                ]
            }
        },
        {
            id: 'l3',
            title: 'Lesson 3: Assignment 3 Module 4',
            duration: '4:30',
            points: 200,
            quizzes: 3,  // Updated to match actual quiz questions
            files: 10,
            type: 'Lesson',
            statusStart: true,
            quiz: {
                id: 'quiz-l3',
                questions: [
                    {
                        id: 'q1',
                        text: 'What are the key benefits of digital transformation?',
                        options: [
                            {
                                id: 'q1a',
                                text: 'A. Improved efficiency and customer experience',
                                isCorrect: true
                            },
                            {
                                id: 'q1b',
                                text: 'B. Higher costs and complexity',
                                isCorrect: false
                            },
                            {
                                id: 'q1c',
                                text: 'C. Reduced automation',
                                isCorrect: false
                            },
                            {
                                id: 'q1d',
                                text: 'D. Less data collection',
                                isCorrect: false
                            }
                        ]
                    },
                    {
                        id: 'q2',
                        text: 'Which is a key component of digital transformation strategy?',
                        options: [
                            {
                                id: 'q2a',
                                text: 'A. Maintaining legacy systems unchanged',
                                isCorrect: false
                            },
                            {
                                id: 'q2b',
                                text: 'B. Data-driven decision making',
                                isCorrect: true
                            },
                            {
                                id: 'q2c',
                                text: 'C. Avoiding cloud technologies',
                                isCorrect: false
                            },
                            {
                                id: 'q2d',
                                text: 'D. Reducing customer touchpoints',
                                isCorrect: false
                            }
                        ]
                    },
                    {
                        id: 'q3',
                        text: 'What role does artificial intelligence play in modern business?',
                        options: [
                            {
                                id: 'q3a',
                                text: 'A. Replacing all human workers',
                                isCorrect: false
                            },
                            {
                                id: 'q3b',
                                text: 'B. Automating repetitive tasks and providing insights',
                                isCorrect: true
                            },
                            {
                                id: 'q3c',
                                text: 'C. Increasing operational complexity',
                                isCorrect: false
                            },
                            {
                                id: 'q3d',
                                text: 'D. Reducing data collection',
                                isCorrect: false
                            }
                        ]
                    }
                ]
            }
        },
        {
            id: 'a1',
            title: 'Assignment 1: Assignment 1 Module 4',
            duration: '1:1',
            points: 10,
            quizzes: 0,
            files: 0,
            type: 'Assignment',
            statusContinue: true,
            quiz: null // Assignments don't have quizzes
        },
        {
            id: 'l4',
            title: 'Lesson 4: Assignment 2 Module 4',
            duration: '2:10',
            points: 1450,
            quizzes: 2,
            files: 5,
            type: 'Lesson',
            statusStart: true,
            quiz: null // No quiz for this lesson yet
        },
        {
            id: 'a2',
            title: 'Assignment 3: Assignment 3 Module 4',
            duration: '4:30',
            points: 200,
            quizzes: 1,
            files: 10,
            type: 'Assignment',
            statusStart: true,
            quiz: null // Assignments don't have quizzes
        }
    ],
    // ...other courses...
};

export default class MyProgramLessons extends LightningElement {
    @api selectedCourse;
    @track activeTab = 'all';
    @track dynamicLessons = [];
    @track isLoading = false;
    @track error;
    @track showLessonsFilter = true; // Controls Lessons Filter visibility
    emptyStateImageUrl = EmptyStateImage;

    // Lifecycle hook to initialize visibility settings
    connectedCallback() {
        console.log('MyProgramLessons connectedCallback - loading visibility settings');
        // Add a small delay to ensure Apex is ready
        setTimeout(() => {
            this.loadVisibilitySettings();
        }, 100);
    }

    // Method to load visibility settings from Apex
    async loadVisibilitySettings() {
        try {
            console.log('Calling isLessonsFilterVisible Apex method...');
            const result = await isLessonsFilterVisible();
            console.log('Lessons Filter visibility result:', result);
            this.showLessonsFilter = result;
        } catch (error) {
            console.error('Error calling isLessonsFilterVisible:', error);
            console.log('Will continue with default showLessonsFilter = true');
            // Don't throw - continue with default value
            this.showLessonsFilter = true;
        }
    }

    // Wire method to get lesson assignments based on selected module
    @wire(getLessonAssignmentsData, { moduleId: '$selectedModuleId' })
    wiredLessons({ error, data }) {
        if (data) {
            this.dynamicLessons = data.assignments || []; // Use assignments property
            this.isLoading = false;
            this.error = undefined;
            console.log('Lesson assignments loaded for myProgramLessons:', this.dynamicLessons);
        } else if (error) {
            this.error = error;
            this.isLoading = false;
            this.dynamicLessons = [];
            console.error('Error loading lesson assignments data:', error);
        }
    }

    // Get the module ID from the selected course
    get selectedModuleId() {
        if (!this.selectedCourse) return null;
        
        // Handle case where selectedCourse might be an object or string
        if (typeof this.selectedCourse === 'object') {
            return this.selectedCourse.id || this.selectedCourse.courseId;
        }
        return this.selectedCourse;
    }

    get courseTitle() {
        try {
            if (!this.selectedCourse) return '';
            
            console.log('courseTitle getter - selectedCourse:', this.selectedCourse);
            console.log('courseTitle getter - selectedCourse type:', typeof this.selectedCourse);
            console.log('courseTitle getter - selectedCourse properties:', Object.keys(this.selectedCourse || {}));
            
            // If selectedCourse is an object from myProgramCourses, extract the course name
            if (typeof this.selectedCourse === 'object') {
                // Priority order for getting the course name:
                // 1. title (from course object)
                // 2. moduleName (from dynamic course data)
                // 3. courseData.title (if nested)
                if (this.selectedCourse.title) {
                    console.log('Using course title:', this.selectedCourse.title);
                    return this.selectedCourse.title;
                } else if (this.selectedCourse.moduleName) {
                    console.log('Using module name:', this.selectedCourse.moduleName);
                    return this.selectedCourse.moduleName;
                } else if (this.selectedCourse.courseData && this.selectedCourse.courseData.title) {
                    console.log('Using nested course title:', this.selectedCourse.courseData.title);
                    return this.selectedCourse.courseData.title;
                }
                
                // Fallback: construct name from moduleCode and title if available
                const moduleCode = this.selectedCourse.moduleCode || this.selectedCourse.courseId || '';
                const courseName = this.selectedCourse.courseName || this.selectedCourse.title || '';
                
                if (moduleCode && courseName) {
                    const displayName = `${moduleCode} - ${courseName}`;
                    console.log('Using constructed name:', displayName);
                    return displayName;
                }
            }
            
            // Handle case where selectedCourse might be a string courseId (fallback)
            let courseId;
            if (typeof this.selectedCourse === 'string') {
                courseId = this.selectedCourse;
            } else if (this.selectedCourse && typeof this.selectedCourse === 'object') {
                courseId = this.selectedCourse.courseId || this.selectedCourse.id;
            } else {
                console.warn('Unexpected selectedCourse type:', typeof this.selectedCourse, this.selectedCourse);
                return '';
            }
            
            console.log('courseTitle getter - extracted courseId for fallback:', courseId);
            
            // Static fallback mapping (for backward compatibility)
            const courseTitleMap = {
                'c1': 'MOD-21 - Grading Course 2',
                'c2': 'MOD-22 - Grading Course 3', 
                'c3': 'MOD-23 - Advanced Lightning Web Components'
            };
            
            const result = courseTitleMap[courseId] || `Module ${courseId}`;
            console.log('courseTitle getter - fallback result:', result);
            return result;
        } catch (error) {
            console.error('Error in courseTitle getter:', error);
            return '';
        }
    }

    get lessons() {
        try {
            console.log('lessons getter - selectedCourse:', this.selectedCourse);
            console.log('lessons getter - dynamicLessons:', this.dynamicLessons);
            
            // If we have dynamic lessons from Apex, use them
            if (this.dynamicLessons && this.dynamicLessons.length > 0) {
                return this.dynamicLessons;
            }
            
            // Fallback to static data if no dynamic lessons are available
            // Handle case where selectedCourse might be an object instead of string
            let courseId;
            if (typeof this.selectedCourse === 'string') {
                courseId = this.selectedCourse;
            } else if (this.selectedCourse && typeof this.selectedCourse === 'object') {
                courseId = this.selectedCourse.courseId || this.selectedCourse.id;
            } else {
                console.warn('lessons getter - Unexpected selectedCourse type:', typeof this.selectedCourse, this.selectedCourse);
                return [];
            }
            
            console.log('lessons getter - extracted courseId:', courseId);
            const result = LESSONS[courseId] || [];
            console.log('lessons getter - found lessons:', result.length);
            return result;
        } catch (error) {
            console.error('Error in lessons getter:', error);
            return [];
        }
    }

    get filteredLessons() {
        if (this.activeTab === 'all') {
            return this.lessons;
        }
        if (this.activeTab === 'lessons') {
            return this.lessons.filter(l => l.type === 'Lesson');
        }
        if (this.activeTab === 'assignments') {
            return this.lessons.filter(l => l.type === 'Assignment');
        }
        return [];
    }

    get allTabClass() {
        return this.activeTab === 'all'
            ? 'slds-button slds-button_neutral slds-is-selected'
            : 'slds-button slds-button_neutral';
    }
    get lessonsTabClass() {
        return this.activeTab === 'lessons'
            ? 'slds-button slds-button_neutral slds-is-selected'
            : 'slds-button slds-button_neutral';
    }
    get assignmentsTabClass() {
        return this.activeTab === 'assignments'
            ? 'slds-button slds-button_neutral slds-is-selected'
            : 'slds-button slds-button_neutral';
    }

    showAll() {
        this.activeTab = 'all';
    }
    showLessons() {
        this.activeTab = 'lessons';
    }
    showAssignments() {
        this.activeTab = 'assignments';
    }

    handleLessonClick(event) {
        const assignmentId = event.currentTarget.dataset.id;
        const lessonAssignment = this.lessons.find(l => l.id === assignmentId);
        
        console.log('Lesson assignment clicked:', assignmentId, lessonAssignment);
        
        if (lessonAssignment) {
            // Extract the courseId properly from selectedCourse object
            let courseId;
            if (typeof this.selectedCourse === 'object') {
                courseId = this.selectedCourse.id || this.selectedCourse.courseId;
            } else {
                courseId = this.selectedCourse;
            }
            
            this.dispatchEvent(new CustomEvent('lessonselect', {
                detail: { 
                    lessonWeekAssignment: lessonAssignment, // Pass the full assignment object
                    lessonWeekAssignmentId: assignmentId, // Pass the assignment ID
                    moduleAssignmentId: lessonAssignment.moduleAssignmentId, // Pass module assignment ID
                    moduleId: lessonAssignment.moduleId, // Pass module ID
                    enrollmentId: lessonAssignment.enrollmentId, // Pass enrollment ID
                    courseId: courseId,
                    selectedCourse: this.selectedCourse // Pass full object too for context
                }
            }));
        } else {
            console.error('Lesson assignment not found:', assignmentId);
        }
    }

    handleStatusButtonClick(event) {
        // Stop the event from bubbling up to the row click handler
        event.stopPropagation();
        
        // Get the lesson ID from the button and trigger the same lesson click logic
        const assignmentId = event.currentTarget.dataset.id;
        const lessonAssignment = this.lessons.find(l => l.id === assignmentId);
        
        console.log('Status button clicked:', assignmentId, lessonAssignment);
        
        if (lessonAssignment) {
            // Update the lesson week assignment status to "In Progress" in the database
            updateLessonWeekAssignmentStatus({ lessonWeekAssignmentId: assignmentId })
                .then(() => {
                    console.log('Status updated to In Progress in database');
                    
                    // Refresh the lessons list to reflect the status change in the background
                    if (this.wiredLessonsResult) {
                        refreshApex(this.wiredLessonsResult);
                    }
                    
                    // Extract the courseId properly from selectedCourse object
                    let courseId;
                    if (typeof this.selectedCourse === 'object') {
                        courseId = this.selectedCourse.id || this.selectedCourse.courseId;
                    } else {
                        courseId = this.selectedCourse;
                    }
                    
                    // Dispatch the lessonselect event with a flag indicating status was just started
                    this.dispatchEvent(new CustomEvent('lessonselect', {
                        detail: { 
                            lessonWeekAssignment: lessonAssignment,
                            lessonWeekAssignmentId: assignmentId,
                            moduleAssignmentId: lessonAssignment.moduleAssignmentId,
                            moduleId: lessonAssignment.moduleId,
                            enrollmentId: lessonAssignment.enrollmentId,
                            courseId: courseId,
                            selectedCourse: this.selectedCourse,
                            statusJustStarted: true // Flag to indicate the status was just updated to "In Progress"
                        }
                    }));
                })
                .catch(error => {
                    console.error('Error updating status:', error);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to update status: ' + (error.body?.message || error.message),
                        variant: 'error'
                    }));
                });
        } else {
            console.error('Lesson assignment not found:', assignmentId);
        }
    }
}