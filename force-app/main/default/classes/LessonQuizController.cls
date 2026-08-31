public without sharing class LessonQuizController {
    
    @AuraEnabled(cacheable=true)
    public static SurveyResultData getExistingQuizResult(Id lessonId, Id enrollmentId) {
        try {
            System.debug('=== getExistingQuizResult START ===');
            System.debug('Lesson ID: ' + lessonId);
            System.debug('Note: Received enrollmentId parameter: ' + enrollmentId + ' (will recalculate for current user)');
            
            // Get the current user and correct enrollment for member/employee
            Id currentUserId = UserInfo.getUserId();
            Id correctEnrollmentId = getEnrollmentForLesson(lessonId, currentUserId);
            
            if (correctEnrollmentId == null) {
                System.debug('No enrollment found for current user for this lesson');
                return null;
            }
            
            System.debug('Correct enrollment ID for current user: ' + correctEnrollmentId);
            enrollmentId = correctEnrollmentId; // Use the correct enrollment ID
            
            // Check for existing survey result using the same logic as hasUserCompletedQuiz
            List<LMS_Survey_Result__c> existingResults = [
                SELECT Id, Lesson__c, Enrollment__c, Module__c, Percentage__c, CreatedDate, Passed__c
                FROM LMS_Survey_Result__c
                WHERE Lesson__c = :lessonId 
                AND Enrollment__c = :enrollmentId
                AND LMS_Survey_Result_Type__c = 'Lesson Quiz'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (existingResults.isEmpty()) {
                System.debug('No existing result found');
                return null;
            }
            
            LMS_Survey_Result__c result = existingResults[0];
            SurveyResultData resultData = new SurveyResultData();
            resultData.id = result.Id;
            resultData.lessonId = result.Lesson__c;
            resultData.enrollmentId = result.Enrollment__c;
            resultData.moduleId = result.Module__c;
            resultData.percentage = result.Percentage__c;
            resultData.completedDate = result.CreatedDate;
            resultData.passed = result.Passed__c != null ? result.Passed__c : false;
            
            System.debug('Found existing result: ' + resultData);
            System.debug('Pass/Fail status: ' + resultData.passed);
            return resultData;
            
        } catch (Exception e) {
            System.debug('Error in getExistingQuizResult: ' + e.getMessage());
            throw new AuraHandledException('Error checking for existing quiz results: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static QuizData getQuizData(Id lessonId) {
        try {
            System.debug('=== getQuizData START ===');
            System.debug('Requested lessonId: ' + lessonId);
            
            LMS_Survey__c survey = findSurveyForLesson(lessonId);
            if (survey == null) {
                System.debug('No survey found for lesson, returning null');
                return null;
            }
            
            System.debug('Survey found, getting questions for survey ID: ' + survey.Id);
            List<LMS_Survey_Question__c> surveyQuestions = getSurveyQuestions(survey.Id);
            System.debug('Survey questions found: ' + surveyQuestions.size());
            
            QuizData result = buildQuizData(survey, surveyQuestions);
            System.debug('Quiz data built successfully');
            System.debug('=== getQuizData END ===');
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error in getQuizData: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving quiz data: ' + e.getMessage());
        }
    }
    
    private static LMS_Survey__c findSurveyForLesson(Id lessonId) {
        System.debug('=== findSurveyForLesson DEBUG START ===');
        System.debug('Input lessonId: ' + lessonId);
        
        List<LMS_Survey__c> surveys = [
            SELECT Id, Survey_Name__c, Lesson__c, Status__c, Survey_Type__c, Passing_Score__c
            FROM LMS_Survey__c 
            WHERE Lesson__c = :lessonId 
            AND Status__c = 'Ready'
            AND Survey_Type__c = 'Quiz'
            LIMIT 1
        ];
        
        System.debug('Total surveys found for lesson: ' + surveys.size());
        
        if (!surveys.isEmpty()) {
            LMS_Survey__c survey = surveys[0];
            System.debug('Found survey - ID: ' + survey.Id + ', Name: ' + survey.Survey_Name__c + ', Status: ' + survey.Status__c + ', Type: ' + survey.Survey_Type__c + ', Passing Score: ' + survey.Passing_Score__c);
        } else {
            System.debug('No surveys found - checking all surveys for this lesson without filters...');
            
            // Additional debug query to see what surveys exist for this lesson
            List<LMS_Survey__c> allSurveys = [
                SELECT Id, Survey_Name__c, Lesson__c, Status__c, Survey_Type__c, Passing_Score__c
                FROM LMS_Survey__c 
                WHERE Lesson__c = :lessonId 
                LIMIT 10
            ];
            
            System.debug('All surveys for lesson (without filters): ' + allSurveys.size());
            for (LMS_Survey__c s : allSurveys) {
                System.debug('Survey found - ID: ' + s.Id + ', Name: ' + s.Survey_Name__c + ', Status: ' + s.Status__c + ', Type: ' + s.Survey_Type__c);
            }
        }
        
        System.debug('=== findSurveyForLesson DEBUG END ===');
        return surveys.isEmpty() ? null : surveys[0];
    }
    
    private static List<LMS_Survey_Question__c> getSurveyQuestions(Id surveyId) {
        return [
            SELECT Id, 
                   Question__c, 
                   Question_Type__c,
                   Correct_Response__c,
                   Response_A__c,
                   Response_B__c,
                   Response_C__c,
                   Response_D__c,
                   Response_E__c
            FROM LMS_Survey_Question__c 
            WHERE LMS_Survey__c = :surveyId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];
    }
    
    public static QuizData buildQuizData(LMS_Survey__c survey, List<LMS_Survey_Question__c> surveyQuestions) {
        QuizData quizData = new QuizData();
        quizData.id = survey.Id;
        quizData.name = survey.Survey_Name__c;
       // quizData.description = survey.Survey_Description__c;
        quizData.questions = new List<QuestionData>();
        
        for (LMS_Survey_Question__c surveyQuestion : surveyQuestions) {
            QuestionData questionData = buildQuestionData(surveyQuestion);
            quizData.questions.add(questionData);
        }
        
        return quizData;
    }
    
    public static QuestionData buildQuestionData(LMS_Survey_Question__c surveyQuestion) {
        QuestionData questionData = new QuestionData();
        questionData.id = surveyQuestion.Id;
        questionData.text = surveyQuestion.Question__c;
        questionData.type = surveyQuestion.Question_Type__c;
        questionData.options = new List<OptionData>();
        
        if (surveyQuestion.Question_Type__c == 'Single Select Response') {
            Set<String> correctResponses = parseCorrectResponses(surveyQuestion.Correct_Response__c);
            questionData.options = buildResponseOptions(surveyQuestion, correctResponses);
        } else if (surveyQuestion.Question_Type__c == 'Short Text Response') {
            // For short text responses, no options are needed
            // The question will be displayed with a text area input
        }
        
        return questionData;
    }
    
    private static Set<String> parseCorrectResponses(String correctResponseField) {
        Set<String> correctResponses = new Set<String>();
        if (String.isNotBlank(correctResponseField)) {
            String[] responses = correctResponseField.split(';');
            for (String response : responses) {
                correctResponses.add(response.trim());
            }
        }
        return correctResponses;
    }
    
    public static List<OptionData> buildResponseOptions(LMS_Survey_Question__c surveyQuestion, Set<String> correctResponses) {
        List<OptionData> options = new List<OptionData>();
        
        addResponseOption(options, 'A', surveyQuestion.Response_A__c, correctResponses);
        addResponseOption(options, 'B', surveyQuestion.Response_B__c, correctResponses);
        addResponseOption(options, 'C', surveyQuestion.Response_C__c, correctResponses);
        addResponseOption(options, 'D', surveyQuestion.Response_D__c, correctResponses);
        addResponseOption(options, 'E', surveyQuestion.Response_E__c, correctResponses);
        
        return options;
    }
    
    public static void addResponseOption(List<OptionData> options, String optionId, String responseText, Set<String> correctResponses) {
        if (String.isNotBlank(responseText)) {
            OptionData option = new OptionData();
            option.id = optionId;
            option.text = optionId + '. ' + responseText;
            option.isCorrect = correctResponses.contains(optionId);
            options.add(option);
        }
    }
    
    @AuraEnabled
    public static void markLessonCompleted(Id lessonId) {
        try {
            // Get current user ID
            Id currentUserId = UserInfo.getUserId();
            
            // Check if the user is a member or employee
            Boolean isMemberOrNone = isContactMemberOrNone(currentUserId);
            
            List<LMS_Lesson_Week_Assignment__c> assignments;
            
            if (isMemberOrNone) {
                // Member: Query using External_Resource__c (Contact)
                Id currentContactId = getCurrentUserContactId(currentUserId);
                if (currentContactId == null) {
                    System.debug('No contact found for member user: ' + currentUserId);
                    return;
                }
                
                assignments = [
                    SELECT Id, Completed__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Lesson__c = :lessonId
                    AND Enrollment__r.External_Resource__c = :currentContactId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
            } else {
                // Non-Member/Employee: Query using Employee relationship
                assignments = [
                    SELECT Id, Completed__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Lesson__c = :lessonId
                    AND Enrollment__r.Employee__r.User__c = :currentUserId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
            }
            
            if (!assignments.isEmpty()) {
                LMS_Lesson_Week_Assignment__c assignment = assignments[0];
                
                // Check if user has permission to update the record
                if (!Schema.sObjectType.LMS_Lesson_Week_Assignment__c.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to update lesson assignments.');
                }
                
                assignment.Completed__c = true;
                assignment.Status__c = 'Completed';
                
                update assignment;
                
                System.debug('Lesson week assignment marked as completed: ' + assignment.Id);
                
                // Check if all assignments in the enrollment are completed
                updateEnrollmentStatusForLesson(lessonId, currentUserId);
            } else {
                System.debug('No lesson week assignment found for lesson: ' + lessonId + ' and user: ' + currentUserId);
            }
            
        } catch (Exception e) {
            System.debug('Error in markLessonCompleted: ' + e.getMessage());
            throw new AuraHandledException('Error marking lesson as completed: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to update enrollment status based on lesson week assignment completion
     */
    public static void updateEnrollmentStatusForLesson(Id lessonId, Id userId) {
        try {
            // Check CRUD permissions for LMS_Enrollment__c
            if (!Schema.sObjectType.LMS_Enrollment__c.isUpdateable()) {
                System.debug('User does not have permission to update LMS_Enrollment__c records');
                return;
            }
            
            // Get the enrollment ID from the lesson
            Id enrollmentId = getEnrollmentForLesson(lessonId, userId);
            
            if (enrollmentId == null) {
                System.debug('No enrollment found for lesson: ' + lessonId);
                return;
            }
            
            // Check if all assignments in this enrollment are completed
            List<LMS_Lesson_Week_Assignment__c> allAssignments = [
                SELECT Id, Status__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Enrollment__c = :enrollmentId
                WITH SECURITY_ENFORCED
            ];
            
            Boolean allCompleted = true;
            for (LMS_Lesson_Week_Assignment__c assign : allAssignments) {
                if (assign.Status__c != 'Completed') {
                    allCompleted = false;
                    break;
                }
            }
            
            // Update enrollment status based on assignment completion
            // Query the enrollment first to avoid REQUIRED_FIELD_MISSING errors
            LMS_Enrollment__c enrollment = [
                SELECT Id, Status__c, Journey__c 
                FROM LMS_Enrollment__c 
                WHERE Id = :enrollmentId 
                LIMIT 1
            ];
            
            // Do not override Unenrolled status
            if (enrollment.Status__c == 'Unenrolled') {
                System.debug('Enrollment is Unenrolled, skipping status update: ' + enrollmentId);
                return;
            }
            
            if (allCompleted) {
                enrollment.Status__c = 'Completed';
                System.debug('All assignments completed - updating enrollment to Completed: ' + enrollmentId);
            } else {
                enrollment.Status__c = 'In Progress';
                System.debug('Some assignments completed - updating enrollment to In Progress: ' + enrollmentId);
            }
            
            update enrollment;
            System.debug('Successfully updated enrollment status: ' + enrollmentId);
            
        } catch (Exception e) {
            System.debug('Error updating enrollment status: ' + e.getMessage());
            // Don't fail the quiz completion - this is a post-completion operation
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isQuizCompleted(Id lessonId) {
        try {
            Id currentUserId = UserInfo.getUserId();
            Id enrollmentId = getEnrollmentForLesson(lessonId, currentUserId);
            
            if (enrollmentId == null) {
                return false;
            }
            
            return hasUserCompletedQuiz(lessonId, enrollmentId);
            
        } catch (Exception e) {
            System.debug('Error checking quiz completion status: ' + e.getMessage());
            return false;
        }
    }
    
    @AuraEnabled
    public static QuizSubmissionResult submitQuizAnswers(Id lessonId, List<QuizAnswer> answers) {
        try {
            System.debug('=== submitQuizAnswers START ===');
            System.debug('Lesson ID: ' + lessonId);
            System.debug('Number of answers: ' + answers.size());
            
            // Get current user and enrollment data
            Id currentUserId = UserInfo.getUserId();
            Id enrollmentId = getEnrollmentForLesson(lessonId, currentUserId);
            
            if (enrollmentId == null) {
                throw new AuraHandledException('No enrollment found for this lesson');
            }
            
            // Get survey ID for this lesson
            LMS_Survey__c survey = findSurveyForLesson(lessonId);
            if (survey == null) {
                throw new AuraHandledException('No quiz found for this lesson');
            }
            
            // Check if quiz has already been completed to prevent duplicate submissions
            if (hasUserCompletedQuiz(lessonId, enrollmentId)) {
                throw new AuraHandledException('You have already completed this quiz. Each quiz can only be taken once.');
            }
            
            // Calculate results from the provided answers
            System.debug('Calculating quiz results...');
            Integer totalQuestions = answers.size();
            Integer correctAnswers = 0;
            
            for (QuizAnswer answer : answers) {
                System.debug('Answer - QuestionId: ' + answer.questionId + ', Selected: ' + answer.selectedAnswer + ', Correct: ' + answer.isCorrect);
                if (answer.isCorrect) {
                    correctAnswers++;
                }
            }
            
            Decimal percentage = totalQuestions > 0 ? (Decimal.valueOf(correctAnswers) / Decimal.valueOf(totalQuestions)) * 100 : 0;
            System.debug('Quiz calculation results:');
            System.debug('- Total Questions: ' + totalQuestions);
            System.debug('- Correct Answers: ' + correctAnswers);
            System.debug('- Percentage: ' + percentage);
            
            // Get passing score from survey (default to 70 if not set)
            Decimal passingScore = survey.Passing_Score__c != null ? survey.Passing_Score__c : 70;
            System.debug('- Passing Score: ' + passingScore);
            
            // Create survey result record
            System.debug('About to call createQuizResult...');
            LMS_Survey_Result__c surveyResult = createQuizResult(lessonId, enrollmentId, survey.Id, totalQuestions, correctAnswers, percentage, passingScore);
            System.debug('createQuizResult completed, survey result ID: ' + surveyResult.Id);
            
            // Create individual survey response records for each question
            System.debug('About to create individual survey responses...');
            createSurveyResponses(surveyResult.Id, answers);
            System.debug('Survey responses created successfully');
            
            // Mark lesson as completed
            markLessonCompleted(lessonId);
            
            System.debug('Quiz submission completed successfully');
            System.debug('=== submitQuizAnswers END ===');
            
            return new QuizSubmissionResult(surveyResult.Id, correctAnswers, totalQuestions, percentage, passingScore);
            
        } catch (Exception e) {
            System.debug('Error in submitQuizAnswers: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error submitting quiz: ' + e.getMessage());
        }
    }
    
    private static Id getEnrollmentForLesson(Id lessonId, Id userId) {
        try {
            // Check if the user is a member or employee
            Boolean isMemberOrNone = isContactMemberOrNone(userId);
            
            List<LMS_Lesson_Week_Assignment__c> assignments;
            
            if (isMemberOrNone) {
                // Member: Query using External_Resource__c (Contact)
                Id currentContactId = getCurrentUserContactId(userId);
                if (currentContactId == null) {
                    return null;
                }
                
                assignments = [
                    SELECT Id, Enrollment__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Lesson__c = :lessonId
                    AND Enrollment__r.External_Resource__c = :currentContactId
                    AND Enrollment__r.Status__c != 'Unenrolled'
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
            } else {
                // Non-Member/Employee: Query using Employee relationship
                assignments = [
                    SELECT Id, Enrollment__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Lesson__c = :lessonId
                    AND Enrollment__r.Employee__r.User__c = :userId
                    AND Enrollment__r.Status__c != 'Unenrolled'
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
            }
            
            return assignments.isEmpty() ? null : assignments[0].Enrollment__c;
            
        } catch (Exception e) {
            System.debug('Error getting enrollment for lesson: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Helper method to check if user's Contact RecordType is 'Member'
     * Returns true if Member, false if External or No Contact
     */
    private static Boolean isContactMemberOrNone(Id userId) {
        try {
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :userId LIMIT 1];
            
            if (users.isEmpty() || users[0].ContactId == null) {
                return false; // No contact, fall back to Employee-based lookup
            }
            
            Id contactId = users[0].ContactId;
            List<Contact> contacts = [
                SELECT Id, RecordType.DeveloperName 
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                return false; // No contact found, fall back to Employee-based lookup
            }
            
            String recordTypeName = contacts[0].RecordType.DeveloperName;
            return recordTypeName == 'Member' || recordTypeName == null;
            
        } catch (Exception e) {
            System.debug('Error checking contact record type: ' + e.getMessage());
            return false; // Default to Employee-based lookup on error
        }
    }
    
    /**
     * Helper method to get user's Contact ID
     * Returns the Contact ID if found, null otherwise
     */
    public static Id getCurrentUserContactId(Id userId) {
        try {
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :userId LIMIT 1];
            
            if (users.isEmpty() || users[0].ContactId == null) {
                return null;
            }
            
            return users[0].ContactId;
        } catch (Exception e) {
            System.debug('Error getting contact ID: ' + e.getMessage());
            return null;
        }
    }
    
    private static Boolean hasUserCompletedQuiz(Id lessonId, Id enrollmentId) {
        try {
            List<LMS_Survey_Result__c> existingResults = [
                SELECT Id
                FROM LMS_Survey_Result__c
                WHERE Lesson__c = :lessonId
                AND Enrollment__c = :enrollmentId
                AND LMS_Survey_Result_Type__c = 'Lesson Quiz'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            Boolean hasCompleted = !existingResults.isEmpty();
            System.debug('User has already completed quiz for lesson ' + lessonId + ': ' + hasCompleted);
            
            return hasCompleted;
            
        } catch (Exception e) {
            System.debug('Error checking existing quiz completion: ' + e.getMessage());
            return false; // If we can't check, allow submission
        }
    }
    
    public static LMS_Survey_Result__c createQuizResult(Id lessonId, Id enrollmentId, Id surveyId, Integer totalQuestions, Integer correctAnswers, Decimal percentage, Decimal passingScore) {
        System.debug('=== createQuizResult START ===');
        System.debug('Input parameters:');
        System.debug('- lessonId: ' + lessonId);
        System.debug('- enrollmentId: ' + enrollmentId);
        System.debug('- surveyId: ' + surveyId);
        System.debug('- totalQuestions: ' + totalQuestions);
        System.debug('- correctAnswers: ' + correctAnswers);
        System.debug('- percentage: ' + percentage);
        System.debug('- passingScore: ' + passingScore);
        
        // Check CRUD permissions
        if (!Schema.sObjectType.LMS_Survey_Result__c.isCreateable()) {
            System.debug('ERROR: User does not have permission to create LMS_Survey_Result__c');
            throw new AuraHandledException('You do not have permission to create survey results.');
        }
        System.debug('CRUD permissions check passed');
        
        // Get module ID from lesson
        System.debug('Querying lesson for module ID...');
        List<LMS_Lesson__c> lessons = [
            SELECT Id, Module__c
            FROM LMS_Lesson__c
            WHERE Id = :lessonId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        System.debug('Lessons found: ' + lessons.size());
        Id moduleId = lessons.isEmpty() ? null : lessons[0].Module__c;
        System.debug('Module ID: ' + moduleId);
        
        // Determine pass/fail based on percentage vs passing score
        Boolean isPassed = percentage >= passingScore;
        System.debug('Pass/Fail determination: ' + (isPassed ? 'PASS' : 'FAIL') + ' (Score: ' + percentage + '%, Required: ' + passingScore + '%)');
        
        System.debug('Creating LMS_Survey_Result__c record...');
        LMS_Survey_Result__c surveyResult = new LMS_Survey_Result__c();
        surveyResult.Lesson__c = lessonId;
        surveyResult.Module__c = moduleId;
        surveyResult.Enrollment__c = enrollmentId;
        surveyResult.Total_Number_of_Questions__c = totalQuestions;
        surveyResult.Total_Correct_Answers__c = correctAnswers;
        surveyResult.Percentage__c = percentage;
        surveyResult.LMS_Survey_Result_Type__c = 'Lesson Quiz';
        surveyResult.Passed__c = isPassed; // Set the Passed checkbox
        
        System.debug('Survey result object created with values:');
        System.debug('- Lesson__c: ' + surveyResult.Lesson__c);
        System.debug('- Module__c: ' + surveyResult.Module__c);
        System.debug('- Enrollment__c: ' + surveyResult.Enrollment__c);
        System.debug('- Total_Number_of_Questions__c: ' + surveyResult.Total_Number_of_Questions__c);
        System.debug('- Total_Correct_Answers__c: ' + surveyResult.Total_Correct_Answers__c);
        System.debug('- Percentage__c: ' + surveyResult.Percentage__c);
        System.debug('- LMS_Survey_Result_Type__c: ' + surveyResult.LMS_Survey_Result_Type__c);
        System.debug('- Passed__c: ' + surveyResult.Passed__c);
        
        try {
            insert surveyResult;
            System.debug('SUCCESS: Survey result record created with ID: ' + surveyResult.Id);
        } catch (Exception e) {
            System.debug('ERROR inserting survey result: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw e;
        }
        
        System.debug('=== createQuizResult END ===');
        return surveyResult;
    }
    
    /**
     * Creates individual survey answer records for each quiz question response
     */
    public static void createSurveyResponses(Id surveyResultId, List<QuizAnswer> answers) {
        System.debug('=== createSurveyResponses START ===');
        System.debug('Survey Result ID: ' + surveyResultId);
        System.debug('Number of answers to process: ' + answers.size());
        
        // Get enrollment ID from the first quiz answer context
        Id enrollmentId = getEnrollmentForQuizAnswers(answers);
        if (enrollmentId == null) {
            System.debug('No enrollment found for creating survey responses');
            return;
        }
        
        List<LMS_Survey_Response__c> surveyResponses = new List<LMS_Survey_Response__c>();
        
        for (QuizAnswer answer : answers) {
            System.debug('Processing answer for question: ' + answer.questionId + ', selected: ' + answer.selectedAnswer + ', correct: ' + answer.isCorrect);
            
            LMS_Survey_Response__c response = new LMS_Survey_Response__c();
            response.Enrollment__c = enrollmentId;
            response.LMS_Survey_Question_ID__c = answer.questionId;
            response.Is_this_Response_Correct__c = answer.isCorrect ? 'Yes' : 'No';
            response.Response__c = answer.selectedAnswer;
            
            surveyResponses.add(response);
        }
        
        if (!surveyResponses.isEmpty()) {
            // Check CRUD permissions
            if (!Schema.sObjectType.LMS_Survey_Response__c.isCreateable()) {
                System.debug('User does not have permission to create LMS_Survey_Response__c records');
                return;
            }
            
            System.debug('About to insert ' + surveyResponses.size() + ' survey response records');
            insert surveyResponses;
            System.debug('Survey response records inserted successfully');
        }
        
        System.debug('=== createSurveyResponses END ===');
    }
    
    /**
     * Gets enrollment ID for creating survey responses
     */
    public static Id getEnrollmentForQuizAnswers(List<QuizAnswer> answers) {
        if (answers.isEmpty()) {
            return null;
        }
        
        // Get the first question's associated lesson
        Id questionId = answers[0].questionId;
        List<LMS_Survey_Question__c> questions = [
            SELECT LMS_Survey__r.Lesson__c
            FROM LMS_Survey_Question__c
            WHERE Id = :questionId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        if (questions.isEmpty()) {
            return null;
        }
        
        Id lessonId = questions[0].LMS_Survey__r.Lesson__c;
        return getEnrollmentForLesson(lessonId, UserInfo.getUserId());
    }
    
    /**
     * Gets the question text for a survey response record
     */
    public static String getQuestionText(Id questionId) {
        try {
            List<LMS_Survey_Question__c> questions = [
                SELECT Question__c
                FROM LMS_Survey_Question__c
                WHERE Id = :questionId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            return questions.isEmpty() ? '' : questions[0].Question__c;
        } catch (Exception e) {
            System.debug('Error getting question text: ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * Deletes existing quiz results and responses to allow retaking
     * Also resets the lesson completion status so it's like taking it the first time
     * @param lessonId The lesson ID for which to delete quiz results
     * @param enrollmentId The enrollment ID for which to delete quiz results
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean deleteQuizResults(Id lessonId, Id enrollmentId) {
        try {
            System.debug('=== deleteQuizResults START ===');
            System.debug('Lesson ID: ' + lessonId);
            System.debug('Note: Received enrollmentId parameter: ' + enrollmentId + ' (will recalculate for current user)');
            
            // Get the current user and correct enrollment for member/employee
            Id currentUserId = UserInfo.getUserId();
            Id correctEnrollmentId = getEnrollmentForLesson(lessonId, currentUserId);
            
            if (correctEnrollmentId == null) {
                System.debug('No enrollment found for current user for this lesson');
                throw new AuraHandledException('No enrollment found for this lesson.');
            }
            
            System.debug('Correct enrollment ID for current user: ' + correctEnrollmentId);
            enrollmentId = correctEnrollmentId; // Use the correct enrollment ID
            
            // Find the existing survey result
            List<LMS_Survey_Result__c> existingResults = [
                SELECT Id
                FROM LMS_Survey_Result__c
                WHERE Lesson__c = :lessonId 
                AND Enrollment__c = :enrollmentId
                AND LMS_Survey_Result_Type__c = 'Lesson Quiz'
                WITH SECURITY_ENFORCED
            ];
            
            if (existingResults.isEmpty()) {
                System.debug('No existing quiz results found to delete');
                // Still continue to reset lesson completion status if needed
            } else {
                System.debug('Found ' + existingResults.size() + ' survey result(s) to delete');
            }
            
            // Find and delete associated survey responses
            List<LMS_Survey_Response__c> responses = [
                SELECT Id
                FROM LMS_Survey_Response__c
                WHERE Enrollment__c = :enrollmentId
                AND LMS_Survey_Question_ID__r.LMS_Survey__r.Lesson__c = :lessonId
            ];
            
            System.debug('Found ' + responses.size() + ' survey response(s) to delete');
            
            // Find the lesson week assignment to reset completion status
            List<LMS_Lesson_Week_Assignment__c> assignments = [
                SELECT Id, Completed__c, Status__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Lesson__c = :lessonId
                AND Enrollment__c = :enrollmentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            System.debug('Found ' + assignments.size() + ' lesson assignment(s) to reset');
            
            // Check delete permissions
            if (!responses.isEmpty() && !Schema.sObjectType.LMS_Survey_Response__c.isDeletable()) {
                System.debug('User does not have permission to delete LMS_Survey_Response__c records');
                throw new AuraHandledException('You do not have permission to delete survey responses.');
            }
            
            if (!existingResults.isEmpty() && !Schema.sObjectType.LMS_Survey_Result__c.isDeletable()) {
                System.debug('User does not have permission to delete LMS_Survey_Result__c records');
                throw new AuraHandledException('You do not have permission to delete survey results.');
            }
            
            // Check update permission for lesson assignments
            if (!assignments.isEmpty() && !Schema.sObjectType.LMS_Lesson_Week_Assignment__c.isUpdateable()) {
                System.debug('User does not have permission to update LMS_Lesson_Week_Assignment__c records');
                throw new AuraHandledException('You do not have permission to update lesson assignments.');
            }
            
            // Delete responses first (child records)
            if (!responses.isEmpty()) {
                delete responses;
                System.debug('Deleted ' + responses.size() + ' survey response(s)');
            }
            
            // Then delete the survey results
            if (!existingResults.isEmpty()) {
                delete existingResults;
                System.debug('Deleted ' + existingResults.size() + ' survey result(s)');
            }
            
            // Reset the lesson completion status to false and set status to In Progress
            if (!assignments.isEmpty()) {
                LMS_Lesson_Week_Assignment__c assignment = assignments[0];
                assignment.Completed__c = false;
                assignment.Status__c = 'In Progress';
                update assignment;
                System.debug('Reset Completed__c to false and Status__c to In Progress for lesson assignment: ' + assignment.Id);
            }
            
            System.debug('=== deleteQuizResults END - SUCCESS ===');
            return true;
            
        } catch (Exception e) {
            System.debug('ERROR in deleteQuizResults: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error deleting quiz results: ' + e.getMessage());
        }
    }
    
    // Data structures for quiz information
    public class QuizData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public List<QuestionData> questions { get; set; }
        
        public QuizData() {
            this.questions = new List<QuestionData>();
        }
    }
    
    public class QuestionData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String text { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public List<OptionData> options { get; set; }
        
        public QuestionData() {
            this.options = new List<OptionData>();
        }
    }
    
    public class OptionData {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String text { get; set; }
        @AuraEnabled public Boolean isCorrect { get; set; }
    }
    
    // Data structures for quiz submission
    public class QuizAnswer {
        @AuraEnabled public Id questionId { get; set; }
        @AuraEnabled public String selectedAnswer { get; set; }
        @AuraEnabled public Boolean isCorrect { get; set; }
    }
    
    public class QuizSubmissionResult {
        @AuraEnabled public Id surveyResultId { get; set; }
        @AuraEnabled public Integer correctAnswers { get; set; }
        @AuraEnabled public Integer totalQuestions { get; set; }
        @AuraEnabled public Decimal percentage { get; set; }
        @AuraEnabled public Decimal passingScore { get; set; }
        @AuraEnabled public Boolean passed { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String status { get; set; } // 'success', 'warning', 'error'
        
        public QuizSubmissionResult(Id surveyResultId, Integer correctAnswers, Integer totalQuestions, Decimal percentage, Decimal passingScore) {
            this.surveyResultId = surveyResultId;
            this.correctAnswers = correctAnswers;
            this.totalQuestions = totalQuestions;
            this.percentage = percentage;
            this.passingScore = passingScore;
            this.passed = percentage >= passingScore; // Use dynamic passing score
            this.status = this.passed ? 'success' : 'warning';
            
            // Generate appropriate message based on pass/fail
            if (this.passed) {
                this.message = 'Congratulations! You passed the quiz with ' + Math.round(percentage) + '%. Your score: ' + correctAnswers + '/' + totalQuestions + '.';
            } else {
                this.message = 'Quiz completed. You scored ' + Math.round(percentage) + '% (' + correctAnswers + '/' + totalQuestions + '). A score of ' + Math.round(passingScore) + '% or higher is required to pass.';
            }
        }
    }
    
    /**
     * Wrapper class for existing survey result data
     */
    public class SurveyResultData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id lessonId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public Id moduleId { get; set; }
        @AuraEnabled public Decimal percentage { get; set; }
        @AuraEnabled public DateTime completedDate { get; set; }
        @AuraEnabled public Boolean passed { get; set; }
    }
}