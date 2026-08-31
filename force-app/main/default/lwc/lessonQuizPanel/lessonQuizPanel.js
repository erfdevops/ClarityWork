import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getQuizData from '@salesforce/apex/LessonQuizController.getQuizData';
import getExistingQuizResult from '@salesforce/apex/LessonQuizController.getExistingQuizResult';
import submitQuizAnswers from '@salesforce/apex/LessonQuizController.submitQuizAnswers';
import markLessonCompleted from '@salesforce/apex/LessonQuizController.markLessonCompleted';
import deleteQuizResults from '@salesforce/apex/LessonQuizController.deleteQuizResults';

export default class LessonQuizPanel extends LightningElement {
    @api quiz; // Quiz data passed from parent component
    @api enrollmentId; // Enrollment ID to check for existing results
    @track currentQuestionIndex = 0;
    @track answers = {};
    @track isQuizCompleted = false;
    @track score = null;
    @track quizPassed = false; // Track if the quiz was passed
    @track processedQuiz = null;
    @track dynamicQuizData = null;
    @track existingResult = null;
    @track isLoading = false;
    @track error = null;
    @track _lessonId;
    @track showRetakeWarning = false;
    
    // Store wire results for refresh
    wiredQuizDataResult;
    wiredExistingResultData;

    // Wire method to get quiz data from Salesforce
    @wire(getQuizData, { lessonId: '$lessonId' })
    wiredQuizData(result) {
        this.wiredQuizDataResult = result;
        const { error, data } = result;
        
        if (data) {
            this.dynamicQuizData = data;
            this.isLoading = false;
            this.error = null;
            this.initializeQuiz();
            console.log('Dynamic quiz data loaded:', this.dynamicQuizData);
        } else if (error) {
            this.error = error;
            this.isLoading = false;
            this.dynamicQuizData = null;
            // Fall back to static quiz or passed quiz
            this.initializeQuiz();
            console.error('Error loading quiz data:', error);
        }
    }

    // Wire method to check for existing quiz results
    @wire(getExistingQuizResult, { lessonId: '$lessonId', enrollmentId: '$enrollmentId' })
    wiredExistingResult(result) {
        this.wiredExistingResultData = result;
        const { error, data } = result;
        
        if (data) {
            this.existingResult = data;
            console.log('Existing quiz result found:', this.existingResult);
        } else if (error) {
            console.error('Error checking for existing quiz result:', error);
            this.existingResult = null;
        }
    }

    connectedCallback() {
        // Initialize quiz data when component loads
        this.initializeQuiz();
    }

    initializeQuiz() {
        // Priority order: dynamicQuizData > passed quiz > fallback sample data
        let quizToUse = null;
        
        if (this.dynamicQuizData && this.dynamicQuizData.questions && this.dynamicQuizData.questions.length > 0) {
            quizToUse = this.dynamicQuizData;
            console.log('Using dynamic quiz data from Salesforce');
        } else if (this.quiz && this.quiz.questions && this.quiz.questions.length > 0) {
            quizToUse = this.quiz;
            console.log('Using passed quiz data');
        }
        
        if (quizToUse) {
            // Process the quiz data to add question numbers and initialize selection state
            this.processedQuiz = {
                ...quizToUse,
                questions: quizToUse.questions.map((question, index) => {
                    // Default to 'Single Select' if no type is specified
                    const questionType = question.type || 'Single Select';
                    
                    const processedQuestion = {
                        ...question,
                        questionNumber: index + 1,
                        type: questionType,
                        // Set question type flags - handle variations in type names
                        isSingleSelect: questionType === 'Single Select' || 
                                       questionType === 'Single Select Response' || 
                                       questionType.toLowerCase().includes('single'),
                        isMultiSelect: questionType === 'Multi Select' || 
                                      questionType === 'Multi Select Response' || 
                                      questionType.toLowerCase().includes('multi'),
                        isShortText: questionType === 'Short Text Response' || 
                                    questionType === 'Short Text' || 
                                    questionType.toLowerCase().includes('text'),
                        textAnswer: (questionType === 'Short Text Response' || 
                                   questionType === 'Short Text' || 
                                   questionType.toLowerCase().includes('text')) ? '' : undefined,
                        options: question.options ? question.options.map(option => ({
                            ...option,
                            selected: false
                        })) : []
                    };
                    
                    // Force isSingleSelect to true if it's not multi or short text
                    if (!processedQuestion.isMultiSelect && !processedQuestion.isShortText) {
                        processedQuestion.isSingleSelect = true;
                    }
                    
                    return processedQuestion;
                })
            };
        } else {
            // Always provide fallback sample data for demo purposes
            this.processedQuiz = {
                questions: [
                    {
                        id: 'q1',
                        questionNumber: 1,
                        type: 'Single Select',
                        isSingleSelect: true,
                        isMultiSelect: false,
                        isShortText: false,
                        text: 'What is the Fourth Industrial Revolution?',
                        options: [
                            {
                                id: 'q1a',
                                text: 'A. It is a reorganization of cheap production and increased productivity',
                                isCorrect: true,
                                selected: false
                            },
                            {
                                id: 'q1b',
                                text: 'B. It is a time when customer expectations are driving the creation of new technologies',
                                isCorrect: false,
                                selected: false
                            },
                            {
                                id: 'q1c',
                                text: 'C. It is a revolution that is very difficult to manage, whether physical and understanding the customer experience',
                                isCorrect: false,
                                selected: false
                            },
                            {
                                id: 'q1d',
                                text: 'D. It is a plan to develop new technology that will eventually overtake risks',
                                isCorrect: false,
                                selected: false
                            }
                        ]
                    },
                    {
                        id: 'q2',
                        questionNumber: 2,
                        type: 'Multi Select',
                        isSingleSelect: false,
                        isMultiSelect: true,
                        isShortText: false,
                        text: 'Which technologies are associated with Industry 4.0? (Select all that apply)',
                        options: [
                            {
                                id: 'q2a',
                                text: 'A. Artificial Intelligence',
                                isCorrect: true,
                                selected: false
                            },
                            {
                                id: 'q2b',
                                text: 'B. Internet of Things (IoT)',
                                isCorrect: true,
                                selected: false
                            },
                            {
                                id: 'q2c',
                                text: 'C. Steam Engine',
                                isCorrect: false,
                                selected: false
                            },
                            {
                                id: 'q2d',
                                text: 'D. Machine Learning',
                                isCorrect: true,
                                selected: false
                            }
                        ]
                    },
                    {
                        id: 'q3',
                        questionNumber: 3,
                        type: 'Short Text Response',
                        isSingleSelect: false,
                        isMultiSelect: false,
                        isShortText: true,
                        text: 'Describe in your own words how digital transformation can benefit a business:',
                        textAnswer: '',
                        options: [] // No options for text questions
                    },
                    {
                        id: 'q4',
                        questionNumber: 4,
                        type: 'Single Select',
                        isSingleSelect: true,
                        isMultiSelect: false,
                        isShortText: false,
                        text: 'Which of the following best describes "smart manufacturing"?',
                        options: [
                            {
                                id: 'q4a',
                                text: 'A. Traditional assembly line production',
                                isCorrect: false,
                                selected: false
                            },
                            {
                                id: 'q4b',
                                text: 'B. Manufacturing with basic automation',
                                isCorrect: false,
                                selected: false
                            },
                            {
                                id: 'q4c',
                                text: 'C. Interconnected systems using IoT, AI, and data analytics',
                                isCorrect: true,
                                selected: false
                            },
                            {
                                id: 'q4d',
                                text: 'D. Manual quality control processes',
                                isCorrect: false,
                                selected: false
                            }
                        ]
                    }
                ]
            };
        }
    }

    get currentQuestion() {
        const question = this.processedQuiz && this.processedQuiz.questions 
            ? this.processedQuiz.questions[this.currentQuestionIndex] 
            : null;
        
        return question;
    }

    get currentQuestionNumber() {
        return this.currentQuestionIndex + 1;
    }

    get totalQuestions() {
        return this.processedQuiz && this.processedQuiz.questions 
            ? this.processedQuiz.questions.length 
            : 0;
    }

    get isFirstQuestion() {
        return this.currentQuestionIndex === 0;
    }

    get isLastQuestion() {
        return this.currentQuestionIndex === this.totalQuestions - 1;
    }

    get allQuestionsAnswered() {
        return Object.keys(this.answers).length === this.totalQuestions;
    }

    get nextButtonLabel() {
        if (this.isLastQuestion && this.allQuestionsAnswered) {
            return 'Submit Quiz';
        }
        return 'Next';
    }

    handleOptionSelect(event) {
        const questionId = event.target.dataset.questionId;
        const optionId = event.target.dataset.optionId;
        
        this.answers = {
            ...this.answers,
            [questionId]: optionId
        };

        // Update the selected state in the options
        this.processedQuiz = {
            ...this.processedQuiz,
            questions: this.processedQuiz.questions.map(question => {
                if (question.id === questionId) {
                    return {
                        ...question,
                        options: question.options.map(option => ({
                            ...option,
                            selected: option.id === optionId
                        }))
                    };
                }
                return question;
            })
        };
    }

    handleMultiOptionSelect(event) {
        const questionId = event.target.dataset.questionId;
        const optionId = event.target.dataset.optionId;
        const isChecked = event.target.checked;
        
        // Get current selected options for this question (array)
        let currentAnswers = this.answers[questionId] || [];
        if (typeof currentAnswers === 'string') {
            currentAnswers = [currentAnswers]; // Convert single answer to array
        }
        
        // Add or remove option from the array
        if (isChecked) {
            if (!currentAnswers.includes(optionId)) {
                currentAnswers.push(optionId);
            }
        } else {
            currentAnswers = currentAnswers.filter(id => id !== optionId);
        }
        
        this.answers = {
            ...this.answers,
            [questionId]: currentAnswers
        };

        // Update the selected state in the options
        this.processedQuiz = {
            ...this.processedQuiz,
            questions: this.processedQuiz.questions.map(question => {
                if (question.id === questionId) {
                    return {
                        ...question,
                        options: question.options.map(option => ({
                            ...option,
                            selected: currentAnswers.includes(option.id)
                        }))
                    };
                }
                return question;
            })
        };
    }

    handleTextAnswerChange(event) {
        const questionId = event.target.dataset.questionId;
        const textValue = event.target.value;
        
        this.answers = {
            ...this.answers,
            [questionId]: textValue
        };

        // Update the text answer in the question
        this.processedQuiz = {
            ...this.processedQuiz,
            questions: this.processedQuiz.questions.map(question => {
                if (question.id === questionId) {
                    return {
                        ...question,
                        textAnswer: textValue
                    };
                }
                return question;
            })
        };
    }

    handlePrevious() {
        if (!this.isFirstQuestion) {
            this.currentQuestionIndex--;
        }
    }

    handleNext() {
        if (this.isLastQuestion && this.allQuestionsAnswered) {
            this.submitQuiz();
        } else if (!this.isLastQuestion) {
            this.currentQuestionIndex++;
        }
    }

    async submitQuiz() {
        try {
            console.log('=== Starting quiz submission ===');
            console.log('Lesson ID:', this.lessonId);
            console.log('Answers:', this.answers);
            
            // Prepare answers for Apex method
            const quizAnswers = this.prepareAnswersForSubmission();
            console.log('Prepared answers for submission:', quizAnswers);
            
            // Call Apex method to submit quiz
            const result = await submitQuizAnswers({
                lessonId: this.lessonId,
                answers: quizAnswers
            });
            
            console.log('Quiz submission result:', result);
            
            // Update UI with results
            this.score = Math.round(result.percentage);
            this.quizPassed = result.passed; // Set the passed flag
            this.isQuizCompleted = true;
            
            // Show success message
            console.log('Quiz completed:', result.message);
            console.log('Quiz passed:', result.passed);
            
            // Additional frontend marking as completed (backup in case Apex didn't complete it)
            if (result.passed && this.lessonId) {
                console.log('Quiz passed, ensuring lesson is marked as completed...');
                await this.markLessonAsCompleted();
            }
            
            // Refresh wire adapters to get updated data
            console.log('Refreshing wire adapters to display updated results...');
            await Promise.all([
                refreshApex(this.wiredExistingResultData),
                refreshApex(this.wiredQuizDataResult)
            ]);
            console.log('Wire adapters refreshed successfully');
            
            // Dispatch event to parent component
            this.dispatchEvent(new CustomEvent('quizcompleted', {
                detail: {
                    lessonId: this.lessonId,
                    score: this.score,
                    answers: this.answers,
                    totalQuestions: result.totalQuestions,
                    correctAnswers: result.correctAnswers,
                    passed: result.passed,
                    message: result.message
                }
            }));
            
        } catch (error) {
            console.error('Error submitting quiz:', error);
            // Show error message to user
            alert('Error submitting quiz: ' + error.body.message);
        }
    }
    
    prepareAnswersForSubmission() {
        const answers = [];
        
        this.processedQuiz.questions.forEach(question => {
            const studentAnswer = this.answers[question.id];
            let selectedAnswer = '';
            let isCorrect = false;
            
            if (question.isSingleSelect) {
                // Single select: get the selected option
                selectedAnswer = studentAnswer || '';
                const selectedOption = question.options.find(opt => opt.id === studentAnswer);
                isCorrect = selectedOption && selectedOption.isCorrect;
                
            } else if (question.isMultiSelect) {
                // Multi select: join selected options
                const selectedOptions = Array.isArray(studentAnswer) ? studentAnswer : [];
                selectedAnswer = selectedOptions.join(',');
                
                // Check if all correct options are selected and no incorrect ones
                const correctOptionIds = question.options.filter(opt => opt.isCorrect).map(opt => opt.id);
                const incorrectOptionIds = question.options.filter(opt => !opt.isCorrect).map(opt => opt.id);
                
                const hasAllCorrect = correctOptionIds.every(id => selectedOptions.includes(id));
                const hasNoIncorrect = selectedOptions.every(id => !incorrectOptionIds.includes(id));
                isCorrect = hasAllCorrect && hasNoIncorrect && selectedOptions.length === correctOptionIds.length;
                
            } else if (question.isShortText) {
                // Short text: always considered correct if answered (not empty)
                selectedAnswer = studentAnswer || '';
                isCorrect = selectedAnswer.trim().length > 0;
            }
            
            answers.push({
                questionId: question.id,
                selectedAnswer: selectedAnswer,
                isCorrect: isCorrect
            });
        });
        
        return answers;
    }

    async markLessonAsCompleted() {
        try {
            await markLessonCompleted({ lessonId: this.lessonId });
            console.log('Lesson marked as completed successfully');
        } catch (error) {
            console.error('Error marking lesson as completed:', error);
        }
    }

    // Handle lesson ID changes
    @api
    set lessonId(value) {
        // Only reset if the lesson ID actually changed
        if (value && value !== this._lessonId) {
            this.resetQuizState();
        }
        this._lessonId = value;
    }

    get lessonId() {
        return this._lessonId;
    }

    get formattedCompletedDate() {
        if (this.existingResult?.completedDate) {
            return new Date(this.existingResult.completedDate).toLocaleDateString();
        }
        return '';
    }

    get formattedPercentage() {
        if (this.existingResult?.percentage != null) {
            const percentage = Number(this.existingResult.percentage);
            return isNaN(percentage) ? '0.00' : percentage.toFixed(2);
        }
        return '';
    }

    resetQuizState() {
        this.currentQuestionIndex = 0;
        this.answers = {};
        this.isQuizCompleted = false;
        this.score = null;
        this.quizPassed = false;
        this.processedQuiz = null;
    }
    
    // Retake Quiz Functionality
    handleRetakeQuiz() {
        this.showRetakeWarning = true;
    }
    
    handleCancelRetake() {
        this.showRetakeWarning = false;
    }
    
    async handleConfirmRetake() {
        this.showRetakeWarning = false;
        this.isLoading = true;
        
        try {
            console.log('=== Starting quiz retake ===');
            console.log('Deleting existing results for lesson:', this.lessonId, 'enrollment:', this.enrollmentId);
            
            // Delete existing quiz results and responses
            const deleteSuccess = await deleteQuizResults({
                lessonId: this.lessonId,
                enrollmentId: this.enrollmentId
            });
            
            if (deleteSuccess) {
                console.log('Previous quiz results deleted successfully');
                
                // Reset the quiz state
                this.resetQuizState();
                
                // Clear existing result to show quiz form
                this.existingResult = null;
                
                // Refresh wire adapters to get updated data (should return null now)
                console.log('Refreshing wire adapters after quiz deletion...');
                await Promise.all([
                    refreshApex(this.wiredExistingResultData),
                    refreshApex(this.wiredQuizDataResult)
                ]);
                console.log('Wire adapters refreshed - quiz should be ready for retake');
                
                // Reinitialize the quiz
                this.initializeQuiz();
                
                // Dispatch event to update badge to "In Progress"
                const retakeEvent = new CustomEvent('quizretake', {
                    detail: {
                        lessonId: this.lessonId,
                        status: 'In Progress'
                    },
                    bubbles: true,
                    composed: true
                });
                this.dispatchEvent(retakeEvent);
                
                console.log('Quiz reset complete - ready for retake');
            } else {
                throw new Error('Failed to delete previous quiz results');
            }
            
        } catch (error) {
            console.error('Error during quiz retake:', error);
            this.error = 'Failed to reset quiz: ' + (error.body?.message || error.message);
        } finally {
            this.isLoading = false;
        }
    }
}