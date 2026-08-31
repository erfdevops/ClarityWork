import { LightningElement, track, wire } from 'lwc';
import getTimelineGroupBy from '@salesforce/apex/CommunityVisibilityHelper.getTimelineGroupBy';

export default class HomepageDashboard extends LightningElement {
    @track selectedTimelineJourneyId = null;
    @track timelineGroupBy = 'Week';
    @track selectedNav = 'home';
    @track selectedCourse = null;
    @track selectedCourseId = '';
    @track selectedLesson = '';
    @track selectedLessonWeekAssignmentId = '';
    @track selectedModuleAssignmentId = '';
    @track selectedModuleId = '';
    @track selectedEnrollmentId = '';
    @track viewingLesson = false;
    @track quizResults = {}; // Store quiz results
    @track preselectedModule = null; // Store preselected module from journey overview
    @track timelineLessonData = null; // Store lesson data from timeline navigation

    @wire(getTimelineGroupBy)
    wiredTimelineGroupBy({ data, error }) {
        if (data) {
            this.timelineGroupBy = data;
        } else if (error) {
            console.error('Error loading timeline group by setting:', error);
        }
    }

    get showWeekTimeline() {
        return this.timelineGroupBy !== 'Module';
    }

    get showModuleTimeline() {
        return this.timelineGroupBy === 'Module';
    }

    get showHomeContent() {
        return this.selectedNav === 'home';
    }

    get showProgramContent() {
        return this.selectedNav === 'program';
    }

    get showVideoContent() {
        return this.selectedNav === 'video';
    }

    get showMyProfileContent() {
        return this.selectedNav === 'myprofile';
    }

    get showMyDocumentsModule() {
        return this.selectedNav === 'myfiles';
    }

    get showMyResourcessModule() {
        return this.selectedNav === 'myresources';
    }

    get showChatterModule() {
        return this.selectedNav === 'mychatter';
    }

    handleNavChange(event) {
        this.selectedNav = event.detail;
        // Reset selected course and lesson viewing state when switching tabs
        if (this.selectedNav !== 'program') {
            this.selectedCourse = null;
            this.viewingLesson = false;
            this.selectedLesson = null;
            this.selectedLessonWeekAssignmentId = '';
            this.selectedModuleAssignmentId = '';
            this.selectedModuleId = '';
            this.selectedEnrollmentId = '';
            this.preselectedModule = null; // Clear preselected module
            this.timelineLessonData = null; // Clear timeline lesson data
        } else {
            // If switching to program tab normally (not via module/timeline navigation), clear preselections
            if (!this.preselectedModule && !this.timelineLessonData) {
                this.preselectedModule = null;
                this.timelineLessonData = null;
            }
        }
    }

    handleCourseChange(event) {
        // Extract the full course object from the event detail
        console.log('Course change event detail:', event.detail);
        console.log('Course change event detail.course:', event.detail.course);
        console.log('Course change event detail.courseId:', event.detail.courseId);
        
        // Use the full course object instead of just the courseId
        this.selectedCourse = event.detail.course || event.detail;
        this.selectedCourseId = this.selectedCourse?.id || this.selectedCourse?.Id || this.selectedCourse;
        
        console.log('Selected course set to:', this.selectedCourse);
        console.log('Selected course type:', typeof this.selectedCourse);
        console.log('Selected course ID set to:', this.selectedCourseId);
        
        // Check if there's timeline lesson data waiting to be processed
        if (this.timelineLessonData) {
            console.log('Auto-selecting lesson from timeline data:', this.timelineLessonData.lessonTitle);
            console.log('Timeline lesson data details:', this.timelineLessonData);
            
            // Set up the lesson viewing properties immediately for timeline navigation
            this.selectedLesson = this.timelineLessonData.timelineItem;
            this.selectedLessonWeekAssignmentId = this.timelineLessonData.itemId;
            this.selectedModuleAssignmentId = this.timelineLessonData.moduleAssignmentId;
            this.selectedModuleId = this.timelineLessonData.moduleId;
            this.selectedEnrollmentId = this.timelineLessonData.enrollmentId;
            this.selectedCourseId = this.timelineLessonData.moduleId;
            
            // Go directly to lesson view for timeline navigation
            this.viewingLesson = true;
            
            console.log('Set lesson view properties for timeline navigation:', {
                selectedModuleId: this.selectedModuleId,
                selectedModuleAssignmentId: this.selectedModuleAssignmentId,
                selectedEnrollmentId: this.selectedEnrollmentId,
                selectedLessonWeekAssignmentId: this.selectedLessonWeekAssignmentId,
                viewingLesson: this.viewingLesson
            });
            
            // Clear timeline lesson data after setting up properties
            this.timelineLessonData = null;
        }
        
        // Clear preselected module after course is selected
        if (this.preselectedModule) {
            console.log('Clearing preselected module after course selection');
            this.preselectedModule = null;
        }
        
        this.view = 'lessons';
    }

    handleLessonSelect(event) {
        console.log('Homepage Dashboard - Lesson assignment selected:', event.detail);
        // Store the lesson week assignment and related IDs
        this.selectedLesson = event.detail.lessonWeekAssignment;
        this.selectedLessonWeekAssignmentId = event.detail.lessonWeekAssignmentId;
        this.selectedModuleAssignmentId = event.detail.moduleAssignmentId;
        this.selectedModuleId = event.detail.moduleId;
        this.selectedEnrollmentId = event.detail.enrollmentId;
        // Use the full selectedCourse object instead of just the courseId
        this.selectedCourse = event.detail.selectedCourse || this.selectedCourse;
        this.selectedCourseId = event.detail.courseId || this.selectedCourseId;
        
        // If the event includes a flag that status was just updated to "In Progress", update it immediately
        if (event.detail.statusJustStarted) {
            console.log('START button was clicked - updating status to In Progress');
            this.selectedLesson = {
                ...this.selectedLesson,
                status: 'In Progress',
                completed: false
            };
        }
        
        this.viewingLesson = true;
        
        // Clear timeline lesson data since lesson has been selected
        this.timelineLessonData = null;
        
        console.log('Homepage Dashboard - viewingLesson set to:', this.viewingLesson);
        console.log('Homepage Dashboard - selectedLesson:', this.selectedLesson);
        console.log('Homepage Dashboard - moduleAssignmentId:', this.selectedModuleAssignmentId);
        console.log('Homepage Dashboard - moduleId:', this.selectedModuleId);
    }

    handleLessonBack() {
        this.viewingLesson = false;
        this.selectedLesson = null;
    }

    handleJourneyChange(event) {
        const { journeyId, journeyName } = event.detail;
        console.log('Journey changed to:', journeyName, 'ID:', journeyId);
        this.selectedTimelineJourneyId = journeyId;
        // Update the journey overview component
        const journeyOverview = this.refs.journeyOverview;
        if (journeyOverview) {
            journeyOverview.handleJourneyChange(journeyId);
        }
    }

    handleModuleNavigation(event) {
        const { moduleId, moduleData, courseName, moduleName, journeyId } = event.detail;
        console.log('Module navigation requested:', moduleName, 'Module ID:', moduleId, 'Journey ID:', journeyId);
        // Store the preselected module data
        this.preselectedModule = {
            moduleId,
            moduleData,
            courseName,
            moduleName
        };
        // Preselect the journey in myProgramCourses if provided
        if (journeyId) {
            this.selectedTimelineJourneyId = journeyId;
        }
        // Switch to the program (Modules) tab
        this.selectedNav = 'program';
        // Update the sidebar to show 'program' as selected
        const sidebarNav = this.refs.sidebarNav;
        if (sidebarNav) {
            sidebarNav.setSelectedNav('program');
        }
        // Reset lesson viewing state when switching via module navigation
        this.viewingLesson = false;
        this.selectedLesson = null;
        this.selectedLessonWeekAssignmentId = '';
        this.selectedModuleAssignmentId = '';
        this.selectedModuleId = '';
        this.selectedEnrollmentId = '';
        console.log('Switched to Modules tab with preselected module:', this.preselectedModule, 'and journey:', this.selectedTimelineJourneyId);
    }

    handleLessonNavigationFromTimeline(event) {
        const { 
            itemId, 
            lessonId, 
            courseId, 
            moduleId, 
            enrollmentId, 
            moduleAssignmentId, 
            timelineItem, 
            lessonTitle 
        } = event.detail;
        
        console.log('Lesson navigation from timeline:', lessonTitle, 'Lesson ID:', lessonId);
        console.log('Timeline item data:', timelineItem);
        console.log('Timeline event.detail:', event.detail);
        console.log('Extracted IDs - moduleId:', moduleId, 'enrollmentId:', enrollmentId, 'moduleAssignmentId:', moduleAssignmentId);
        
        // Extract module name from subtitle (remove "Module: " prefix if present)
        // Timeline subtitle format is "Module: MOD-0001", we want just "MOD-0001"
        const moduleName = timelineItem.subtitle ? 
            timelineItem.subtitle.replace(/^Module:\s*/, '') : 'Module';
        
        // Create a preselected module for course auto-selection
        // Note: timeline sends lesson name in 'title' and module name in 'subtitle' with "Module: " prefix
        this.preselectedModule = {
            moduleId: moduleId,
            moduleData: {
                id: moduleId,
                courseId: moduleId
            },
            courseName: moduleName, // Use cleaned module name
            moduleName: moduleName  // Use cleaned module name
        };
        
        // Store the lesson data for auto-selection after course is loaded
        this.timelineLessonData = {
            itemId,
            lessonId,
            courseId,
            moduleId,
            enrollmentId,
            moduleAssignmentId,
            timelineItem,
            lessonTitle
        };
        
        // Switch to the program (Modules) tab first
        this.selectedNav = 'program';
        
        // Update the sidebar to show 'program' as selected
        const sidebarNav = this.refs.sidebarNav;
        if (sidebarNav) {
            sidebarNav.setSelectedNav('program');
        }
        
        // Reset lesson viewing state initially
        this.viewingLesson = false;
        this.selectedLesson = null;
        this.selectedLessonWeekAssignmentId = '';
        this.selectedModuleAssignmentId = '';
        this.selectedModuleId = '';
        this.selectedEnrollmentId = '';

        // Now set the lesson/module selection to mimic myProgramLessons click
        // Create a LessonAssignmentWrapper-like structure from timelineItem
        // This ensures compatibility with lessonListPanel's expected structure
        this.selectedLesson = {
            id: itemId, // Lesson Week Assignment ID
            lessonId: lessonId,
            name: timelineItem?.title || 'Lesson', // Lesson name
            lessonName: timelineItem?.title || 'Lesson', // Lesson name for display
            title: timelineItem?.title || 'Lesson', // Display title (lesson name)
            type: timelineItem?.type || 'Lesson',
            status: timelineItem?.status,
            completed: timelineItem?.completed || false,
            enrollmentId: enrollmentId,
            moduleId: moduleId,
            moduleAssignmentId: moduleAssignmentId
        };
        this.selectedLessonWeekAssignmentId = itemId;
        this.selectedModuleAssignmentId = moduleAssignmentId;
        this.selectedModuleId = moduleId;
        this.selectedEnrollmentId = enrollmentId;
        this.selectedCourseId = moduleId;
        // Set selectedCourse to match the structure used by myProgramLessons
        // Use cleaned module name (without "Module: " prefix) for display in lessonListPanel
        this.selectedCourse = {
            id: moduleId,
            courseId: moduleId,
            title: moduleName, // Clean module name for display in lessonListPanel
            moduleName: moduleName,
            fromTimeline: true // Flag to indicate this came from timeline
        };
        this.viewingLesson = true;

        console.log('Navigating to Modules tab from timeline with preselected module and lesson:', {
            moduleId,
            lessonId,
            lessonTitle,
            moduleName,
            selectedCourse: this.selectedCourse,
            selectedLesson: this.selectedLesson
        });
    }

    handleQuizCompleted(event) {
        const { lessonId, lessonTitle, score, answers, totalQuestions, correctAnswers, passed } = event.detail;
        
        // Store quiz results
        this.quizResults = {
            ...this.quizResults,
            [lessonId]: {
                lessonTitle,
                score,
                answers,
                totalQuestions,
                correctAnswers,
                passed,
                completedAt: new Date().toISOString()
            }
        };

        console.log('Quiz completed for lesson:', lessonTitle, 'Score:', score + '%', 'Passed:', passed);
        
        // If the quiz was passed, immediately update the badge to "Completed"
        if (passed && this.selectedLesson) {
            console.log('Quiz passed - updating badge to Completed');
            this.selectedLesson = {
                ...this.selectedLesson,
                status: 'Completed',
                completed: true
            };
        }
        
        // Show completion message
        if (passed) {
            this.showSuccessMessage(`Congratulations! You completed "${lessonTitle}" with a score of ${score}%!`);
        } else {
            this.showInfoMessage(`Quiz completed for "${lessonTitle}" with a score of ${score}%. Consider reviewing the content.`);
        }

        // Trigger a refresh in the background to sync with database
        const lessonListPanel = this.refs.lessonListPanel;
        if (lessonListPanel && lessonListPanel.refresh) {
            console.log('Triggering background refresh of lesson list after quiz completion');
            lessonListPanel.refresh().catch(error => {
                console.error('Error during background refresh:', error);
            });
        }
    }

    handleQuizRetake(event) {
        const { lessonId, status } = event.detail;
        
        console.log('Quiz retake - updating badge to In Progress');
        
        // Update the badge to "In Progress"
        if (this.selectedLesson) {
            this.selectedLesson = {
                ...this.selectedLesson,
                status: 'In Progress',
                completed: false
            };
        }
        
        // Trigger a refresh in the background to sync with database
        const lessonListPanel = this.refs.lessonListPanel;
        if (lessonListPanel && lessonListPanel.refresh) {
            console.log('Triggering background refresh of lesson list after quiz retake');
            lessonListPanel.refresh().catch(error => {
                console.error('Error during background refresh:', error);
            });
        }
    }

    handleAssignmentSubmitted(event) {
        const { lessonId, lessonTitle, files, submissionTime } = event.detail;
        
        console.log('Assignment submitted:', {
            lessonId,
            lessonTitle,
            files,
            submissionTime
        });

        // Immediately update the selected lesson status to "Completed"
        if (this.selectedLesson) {
            this.selectedLesson = {
                ...this.selectedLesson,
                status: 'Completed',
                completed: true
            };
            console.log('Selected lesson status immediately updated to: Completed');
        }

        // Trigger a refresh in the background to sync with database
        const lessonListPanel = this.refs.lessonListPanel;
        if (lessonListPanel && lessonListPanel.refresh) {
            console.log('Triggering background refresh of lesson list');
            lessonListPanel.refresh().catch(error => {
                console.error('Error during background refresh:', error);
            });
        }

        // Show success message
        this.showSuccessMessage(`Assignment "${lessonTitle}" submitted successfully with ${files.length} file(s)!`);
    }

    showSuccessMessage(message) {
        // In a real implementation, you might use lightning:notificationsLibrary
        console.log('SUCCESS:', message);
    }

    showInfoMessage(message) {
        // In a real implementation, you might use lightning:notificationsLibrary
        console.log('INFO:', message);
    }

    handleProfileNavigation(event) {
        const page = event.detail.page;
        if (page) {
            this.selectedNav = page;
            // Update sidebar selection
            const sidebar = this.refs.sidebarNav;
            if (sidebar) {
                sidebar.setSelectedNav(page);
            }
        }
    }

    handleShowProfilePage(event) {
        this.selectedNav = event.detail;
    }
}