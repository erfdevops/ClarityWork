import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLessonDetails from '@salesforce/apex/MyProgramLessonsController.getLessonDetails';
import getVideoFile from '@salesforce/apex/FileUploadController.getVideoFile';
import saveExternalLessonScore from '@salesforce/apex/MyProgramLessonsController.saveExternalLessonScore';
import isElementVisible from '@salesforce/apex/CommunityVisibilityHelper.isElementVisible';
import getDefaultPdfForLessonContent from '@salesforce/apex/CommunityVisibilityHelper.getDefaultPdfForLessonContent';
import { CurrentPageReference } from 'lightning/navigation';
import EmptyStateImage from '@salesforce/resourceUrl/EmptyState';

export default class LessonContentPanel extends LightningElement {
    @track lessonDetails;
    @track isLoading = true;
    @track error;
    @track _lessonWeekAssignment;
    @track isExpanded = true; // Default to expanded
    @track currentView = 'content'; // 'content' or 'pdf'
    @track showExternalScoreModal = false; // Controls modal visibility
    @track externalScore = null; // Stores the input score value
    @track isSavingScore = false; // Loading state for score save
    @track externalScoreVisible = true; // Controls external score feature visibility based on community settings
    @api lessonWeekAssignmentId; // The ID of the lesson week assignment
    @track hasVideoFile = false;
    @track videoFileData;
    emptyStateImageUrl = EmptyStateImage;

    connectedCallback() {
        // Ensure default view is content and expanded state
        this.currentView = 'content';
        this.isExpanded = true;
        console.log('LessonContentPanel initialized with view:', this.currentView, 'expanded:', this.isExpanded);
    }

    // Wire method to get lesson details from Salesforce
    @wire(getLessonDetails, { lessonId: '$lessonId' })
    wiredLessonDetails({ error, data }) {
        if (data) {
            this.lessonDetails = data;
            this.isLoading = false;
            this.error = undefined;
            console.log('Lesson details loaded:', this.lessonDetails);
        } else if (error) {
            this.error = error;
            this.isLoading = false;
            this.lessonDetails = null;
            console.error('Error loading lesson details:', error);
        }
    }

    // Wire method to check for video files
    @wire(getVideoFile, { lessonId: '$lessonId' })
    wiredVideoFile({ error, data }) {
        if (data) {
            this.hasVideoFile = true;
            this.videoFileData = data;
            console.log('Video file found for lesson:', data.fileName);
        } else if (error) {
            this.hasVideoFile = false;
            this.videoFileData = null;
            console.log('No video file found for lesson or error:', error);
        } else {
            this.hasVideoFile = false;
            this.videoFileData = null;
        }
    }

    // Wire method to determine default view (Content vs PDF) from community settings
    @wire(getDefaultPdfForLessonContent)
    wiredDefaultPdfSetting({ error, data }) {
        if (data !== undefined && data !== null) {
            this.currentView = data ? 'pdf' : 'content';
            console.log('Default PDF setting loaded, currentView set to:', this.currentView);
        } else if (error) {
            // On error, keep default 'content' view
            console.error('Error loading default PDF for lesson content setting:', error);
        }
    }

    // Wire method to check community visibility settings for external score
    @wire(isElementVisible)
    wiredVisibility({ error, data }) {
        if (data !== undefined) {
            this.externalScoreVisible = data;
            console.log('External score visibility setting:', data);
        } else if (error) {
            // On error, default to visible
            this.externalScoreVisible = true;
            console.error('Error checking visibility setting:', error);
        }
    }

    get lessonId() {
        return this.lessonWeekAssignment?.lessonId;
    }

    get enrollmentId() {
        return this.lessonWeekAssignment?.enrollmentId;
    }

    // Handle lesson week assignment changes
    @api
    set lessonWeekAssignment(value) {
        this._lessonWeekAssignment = value;
        console.log('lessonWeekAssignment set:', value);
        console.log('externalLesson value:', value?.externalLesson);
        console.log('externalLessonScore value:', value?.externalLessonScore);
        if (value?.lessonId) {
            this.isLoading = true;
            this.error = undefined;
        }
    }

    get lessonWeekAssignment() {
        return this._lessonWeekAssignment;
    }

    get lessonTitle() {
        return this.lessonDetails?.title || 'Loading...';
    }

    get contentStyle() {
        if (this.isExpanded) {
            return 'overflow-y: visible; height: auto; min-height: auto; max-height: none;';
        }
        return '';
    }

    get isContentView() {
        return this.currentView === 'content';
    }

    get isPdfView() {
        return this.currentView === 'pdf';
    }

    get contentViewVariant() {
        return this.currentView === 'content' ? 'brand' : 'neutral';
    }

    get pdfViewVariant() {
        return this.currentView === 'pdf' ? 'brand' : 'neutral';
    }

    get expandIcon() {
        return this.isExpanded ? 'utility:contract_alt' : 'utility:expand_alt';
    }

    get expandButtonText() {
        return this.isExpanded ? 'Collapse' : 'Expand';
    }

    showContentView() {
        this.currentView = 'content';
        console.log('Switched to content view');
    }

    showPdfView() {
        this.currentView = 'pdf';
        console.log('Switched to PDF view');
    }

    toggleExpand() {
        this.isExpanded = !this.isExpanded;
        console.log('Panel expanded:', this.isExpanded);
    }

    get lessonHtml() {
        if (!this.lessonDetails) {
            return '';
        }

        let content = '';

        // Add prerequisites section if available
        if (this.lessonDetails.prerequisites) {
            content += `
                <div class="lesson-section">
                    <h3 class="lesson-section-title">Prerequisites</h3>
                    <div class="lesson-section-content">
                        ${this.lessonDetails.prerequisites}
                    </div>
                </div>
            `;
        }

        // Add learning objectives section if available
        if (this.lessonDetails.learningObjectives) {
            content += `
                <div class="lesson-section">
                    <h3 class="lesson-section-title">Learning Objectives</h3>
                    <div class="lesson-section-content">
                        ${this.lessonDetails.learningObjectives}
                    </div>
                </div>
            `;
        }

        // Add main lesson content if available
        if (this.lessonDetails.content) {
            content += `
                <div class="lesson-section">
                    <h3 class="lesson-section-title">Lesson Content</h3>
                    <div class="lesson-section-content">
                        ${this.lessonDetails.content}
                    </div>
                </div>
            `;
        }

        // Fallback if no content available
        if (!content) {
            content = '<p>No lesson content available.</p>';
        }
        
        return content;
    }

    get hasQuiz() {
        return this.lessonWeekAssignment && this.lessonWeekAssignment.quizzes && this.lessonWeekAssignment.quizzes > 0;
    }

    get isLesson() {
        return this.lessonWeekAssignment && this.lessonWeekAssignment.type === 'Lesson';
    }

    get isAssignment() {
        return this.lessonWeekAssignment && this.lessonWeekAssignment.type === 'Assignment';
    }

    get lessonStatus() {
        if (!this.lessonWeekAssignment) {
            return null;
        }
        
        // Use the status field if available
        if (this.lessonWeekAssignment.status) {
            return this.lessonWeekAssignment.status;
        }
        
        // Fallback to completed field
        if (this.lessonWeekAssignment.completed) {
            return 'Completed';
        }
        
        // Default status
        return 'Not Started';
    }

    get statusClass() {
        const status = this.lessonStatus;
        if (status === 'Completed') {
            return 'status-badge status-completed';
        } else if (status === 'In Progress') {
            return 'status-badge status-in-progress';
        }
        return 'status-badge status-not-started';
    }

    get statusIcon() {
        const status = this.lessonStatus;
        if (status === 'Completed') {
            return 'utility:check';
        } else if (status === 'In Progress') {
            return 'utility:hourglass';
        }
        return 'utility:clock';
    }

    get assignmentDueDate() {
        if (this.lessonWeekAssignment?.assignmentEndDate) {
            const date = new Date(this.lessonWeekAssignment.assignmentEndDate);
            return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
        }
        return null;
    }

    get assignmentExtensionDate() {
        if (this.lessonWeekAssignment?.assignmentExtensionDate) {
            const date = new Date(this.lessonWeekAssignment.assignmentExtensionDate);
            return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
        }
        return null;
    }

    // External lesson score getters
    get isExternalLesson() {
        // Check lessonWeekAssignment first (has the field from wrapper), fallback to lessonDetails
        const fromAssignment = this.lessonWeekAssignment?.externalLesson === true;
        const fromDetails = this.lessonDetails?.externalLesson === true;
        const result = fromAssignment || fromDetails;
        console.log('isExternalLesson check:', { fromAssignment, fromDetails, result });
        return result;
    }

    get hasExternalScore() {
        const result = this.lessonWeekAssignment?.externalLessonScore != null && 
               this.lessonWeekAssignment?.externalLessonScore !== undefined;
        console.log('hasExternalScore:', result, this.lessonWeekAssignment?.externalLessonScore);
        return result;
    }

    get externalLessonScore() {
        if (this.hasExternalScore) {
            return this.lessonWeekAssignment.externalLessonScore.toFixed(2);
        }
        return null;
    }

    get showExternalScoreDisplay() {
        const result = this.isExternalLesson && this.hasExternalScore && this.externalScoreVisible;
        console.log('showExternalScoreDisplay:', result);
        return result;
    }

    get showExternalScoreButton() {
        const result = this.isExternalLesson && !this.hasExternalScore && this.externalScoreVisible;
        console.log('showExternalScoreButton:', result);
        return result;
    }

    renderedCallback() {
        // Only inject HTML content when in content view
        if (this.currentView === 'content') {
            const container = this.template.querySelector('.lesson-html-content');
            if (container && this.lessonHtml) {
                container.innerHTML = this.lessonHtml;
            }
        }
    }

    // Force re-render when lesson details change
    @api
    refresh() {
        this.requestUpdate();
    }

    handleQuizCompleted(event) {
        const { lessonId, score, answers, totalQuestions, correctAnswers } = event.detail;
        
        console.log('Quiz completed:', {
            lessonId,
            score,
            answers,
            totalQuestions,
            correctAnswers
        });

        // Dispatch event to parent component (homepage dashboard)
        this.dispatchEvent(new CustomEvent('quizcompleted', {
            detail: {
                lessonId: this.lessonId,
                lessonTitle: this.lessonTitle,
                score,
                answers,
                totalQuestions,
                correctAnswers,
                passed: score >= 70 // Consider 70% as passing grade
            },
            bubbles: true
        }));

        // Show success message or handle lesson completion logic
        this.showQuizCompletionMessage(score);
    }

    showQuizCompletionMessage(score) {
        // You could add a toast message or other UI feedback here
        if (score >= 70) {
            console.log('Congratulations! You passed the quiz with a score of ' + score + '%');
        } else {
            console.log('Quiz completed with a score of ' + score + '%. Consider reviewing the lesson content.');
        }
    }

    handleAssignmentSubmitted(event) {
        const { files, timestamp } = event.detail;
        
        console.log('Assignment submitted:', {
            lessonId: this.lessonId,
            lessonTitle: this.lessonTitle,
            files: files,
            submissionTime: timestamp
        });

        // Dispatch event to parent component (homepage dashboard)
        this.dispatchEvent(new CustomEvent('assignmentsubmitted', {
            detail: {
                lessonId: this.lessonId,
                lessonTitle: this.lessonTitle,
                files: files,
                submissionTime: timestamp,
                studentId: 'current-user-id' // In real implementation, get from user context
            },
            bubbles: true
        }));

        // Show success message
        this.showAssignmentSubmissionMessage(files.length);
    }

    showAssignmentSubmissionMessage(fileCount) {
        console.log(`Assignment submission successful! ${fileCount} file(s) uploaded for "${this.lessonTitle}"`);
    }

    // External score modal handlers
    handleOpenExternalScoreModal() {
        this.showExternalScoreModal = true;
        this.externalScore = null; // Reset score
    }

    handleCloseExternalScoreModal() {
        this.showExternalScoreModal = false;
        this.externalScore = null;
    }

    handleExternalScoreChange(event) {
        const value = parseFloat(event.target.value);
        
        // Validate max value of 100
        if (value > 100) {
            event.target.value = 100;
            this.externalScore = 100;
        } else if (value < 0) {
            event.target.value = 0;
            this.externalScore = 0;
        } else {
            this.externalScore = value;
        }
    }

    handleSaveExternalScore() {
        // Validate score is entered
        if (this.externalScore == null || this.externalScore === '') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please enter a score value.',
                    variant: 'error'
                })
            );
            return;
        }

        // Validate score range
        if (this.externalScore < 0 || this.externalScore > 100) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Score must be between 0 and 100.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isSavingScore = true;

        // Call Apex method to save score
        saveExternalLessonScore({ 
            lessonWeekAssignmentId: this.lessonWeekAssignmentId, 
            score: this.externalScore 
        })
        .then((result) => {
            this.isSavingScore = false;
            this.showExternalScoreModal = false;
            
            // Update local data
            if (this._lessonWeekAssignment) {
                this._lessonWeekAssignment = {
                    ...this._lessonWeekAssignment,
                    externalLessonScore: this.externalScore,
                    completed: true,
                    status: 'Completed'
                };
            }

            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `External lesson score of ${this.externalScore} saved successfully!`,
                    variant: 'success'
                })
            );

            // Dispatch event to parent for refresh
            this.dispatchEvent(new CustomEvent('scoresubmitted', {
                detail: {
                    lessonId: this.lessonId,
                    score: this.externalScore,
                    surveyResultId: result
                },
                bubbles: true
            }));

            // Reset score input
            this.externalScore = null;
        })
        .catch((error) => {
            this.isSavingScore = false;
            console.error('Error saving external score:', error);
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'An error occurred while saving the score.',
                    variant: 'error'
                })
            );
        });
    }
}